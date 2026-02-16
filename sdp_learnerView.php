<?php include('sdp_header.php'); ?>

<?php
// Initialize database connection
include('connection.php');

// Check if 'classID' is set in the session
if (isset($_SESSION['classID'])) {
    $selectedClassName = $_SESSION['classID'];
} else {
    echo "Error: Class name not set in the session.";
}

// Check if 'class' is passed in the URL
if (isset($_GET['class'])) {
    $selectedClassName = urldecode($_GET['class']);
    $_SESSION['classID'] = $selectedClassName;
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Learner Profile</title>
    <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css">
    <style>
        /* Address hint styling */
        .address-hint {
            display: block;
            font-size: 0.875rem;
            font-weight: normal;
            color: #6c757d;
            margin-top: 0.25rem;
        }

        /* Calendar table styling */
        .month-tabs .table {
            width: 100%;
            table-layout: fixed;
        }
        .month-tabs .calendar-day {
            vertical-align: top;
            min-height: 100px;
            padding: 5px;
            font-size: 12px;
        }
        .month-tabs .calendar-day small {
            display: block;
            margin-top: 2px;
        }
        .month-tabs .holiday { color: red; }
        .month-tabs .weekend { color: blue; }
        .month-tabs .absent { color: orange; }
        .month-tabs .pending { color: gray; }
        .month-tabs img { max-width: 80px; max-height: 50px; }

        /* Status highlighting */
        .text-verified {
            color: #28a745 !important; /* Green for Verified */
            font-weight: bold;
        }
        .text-approved {
            color: #28a745 !important; /* Green for Approved */
            font-weight: bold;
        }
        .text-declined {
            color: #dc3545 !important; /* Red for Declined */
            font-weight: bold;
        }
        .text-pending {
            color: #ffc107 !important; /* Yellow for Pending */
            font-weight: bold;
        }
        .text-secondary {
            color: #6c757d !important; /* Gray for unknown statuses */
        }

        /* Alert styling */
        .alert-success {
            background-color: #d4edda;
            border-color: #c3e6cb;
            color: #155724;
        }
        .alert-danger {
            background-color: #f8d7da;
            border-color: #f5c6cb;
            color: #721c24;
        }

        /* Custom file input styling */
        .custom-file-input-wrapper {
            position: relative;
            width: 100%;
            height: 38px;
        }
        .custom-file-input-wrapper .form-control-file {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            opacity: 0;
            cursor: pointer;
            z-index: 4;
        }
        .custom-file-input-display {
            display: flex;
            align-items: center;
            justify-content: space-between;
            border: 1px solid #ced4da;
            border-radius: 0.25rem;
            padding: 0.375rem 0.75rem;
            background-color: #fff;
            height: 100%;
            width: 100%;
            position: relative;
            overflow: hidden;
            z-index: 2;
        }
        .custom-file-input-display span {
            flex-grow: 1;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            color: #495057;
        }
        .custom-file-input-display button {
            margin-left: 10px;
            z-index: 3;
        }
        .progress {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            display: none;
            border-radius: 0.25rem;
            z-index: 1;
            background-color: transparent;
        }
        .progress-bar {
            transition: width 0.3s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 0.875rem;
            color: #fff;
            opacity: 0.8;
            background-color: #28a745 !important;
        }
        .btn-primary:disabled {
            opacity: 0.65;
            cursor: not-allowed;
        }
    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="d-flex flex-column-reverse">
            <div class="content-wrapper w-100">
                <div class="container-fluid page-content">
                    <div class="row">
                        <div class="col-md-10 ms-auto padding-right">
                            <div class="page-header">
                                <button class="btn btn-primary" onclick="goBack()">
                                    ← Back
                                </button>
                            </div>
                            <div class="col-lg-12 grid-margin stretch-card">
                                <div class="card">
                                    <div class="card-body">
                                        <h4>LEARNER PROFILE</h4>
                                        <div class="container mt-5 learner-tabs">
                                            <ul class="nav nav-tabs" id="learnerTabs" role="tablist">
                                                <li class="nav-item">
                                                    <a class="nav-link active" id="learner-tab1-tab" data-toggle="tab" href="#learner-tab1" role="tab" aria-controls="learner-tab1" aria-selected="true">Learner info</a>
                                                </li>
                                                <li class="nav-item">
                                                    <a class="nav-link" id="learner-tab2-tab" data-toggle="tab" href="#learner-tab2" role="tab" aria-controls="learner-tab2" aria-selected="false">Documents</a>
                                                </li>
                                                <li class="nav-item">
                                                    <a class="nav-link" id="learner-tab3-tab" data-toggle="tab" href="#learner-tab3" role="tab" aria-controls="learner-tab3" aria-selected="false">POE</a>
                                                </li>
                                                <li class="nav-item"> 
                                                    <a class="nav-link" id="learner-tab4-tab" data-toggle="tab" href="#learner-tab4" role="tab" aria-controls="learner-tab4" aria-selected="false">Report</a>
                                                </li>
                                            </ul>
                                            <div class="tab-content" id="learnerTabsContent">
                                                <!-- Tab 1: Learner Info -->
                                                <div class="tab-pane fade show active" id="learner-tab1" role="tabpanel" aria-labelledby="learner-tab1-tab">
                                                    <?php
                                                    $LearnerID = isset($_GET['LearnerID']) ? $_GET['LearnerID'] : '';
                                                    $learnerData = getLearnerDetails($conn, $LearnerID);
                                                    // echo $LearnerID;

                                                    define('WEB_BASE_URL', 'https://www.rlms.rlms.co.za/');

                                                    function isMobileDevice() {
                                                        return preg_match("/(android|webos|iphone|ipad|ipod|blackberry|iemobile|opera mini)/i", $_SERVER['HTTP_USER_AGENT']) || (isset($_SERVER['HTTP_X_WAP_PROFILE']) || isset($_SERVER['HTTP_PROFILE']));
                                                    }

                                                    $image_url = '../assets/img/avatar6.png';
                                                    if ($learnerData !== null && !empty($learnerData['profile_image'])) {
                                                        $image_path = $learnerData['profile_image'];
                                                        $file_name = strpos($image_path, 'learnerImages/') === 0 ? substr($image_path, strlen('learnerImages/')) : $image_path;
                                                        $folders = [
                                                            'learnerImages/' => $_SERVER['DOCUMENT_ROOT'] . '/learnerImages/',
                                                            '' => $_SERVER['DOCUMENT_ROOT'] . '/',
                                                            'mobile/learnerImages/' => $_SERVER['DOCUMENT_ROOT'] . '/mobile/learnerImages/',
                                                            'mobile/' => $_SERVER['DOCUMENT_ROOT'] . '/mobile/'
                                                        ];
                                                        $preferred_folders = isMobileDevice() 
                                                            ? ['mobile/learnerImages/', 'mobile/', 'learnerImages/', '']
                                                            : ['learnerImages/', '', 'mobile/learnerImages/', 'mobile/'];
                                                        foreach ($preferred_folders as $web_folder) {
                                                            $server_path = $folders[$web_folder];
                                                            $file_path = $server_path . $file_name;
                                                            if (file_exists($file_path)) {
                                                                $image_url = WEB_BASE_URL . $web_folder . $file_name;
                                                                break;
                                                            }
                                                        }
                                                    }

                                                    if ($learnerData !== null) {
                                                    ?>
                                                        <form action="update_learner.php" method="POST" id="learnerForm" onsubmit="return validateForm()">
                                                            <div class="row">
                                                                <div class="col-lg-6">
                                                                    <div class="container border p-3 mb-3">
                                                                        <h5>Learner Details</h5>
                                                                        <div class="form-group row align-items-center">
                                                                            <div class="col-lg-6 text-center">
                                                                                <span class="profile-picture">
                                                                                    <img class="rounded-square-image img-fluid" alt="Avatar" id="avatar2" src="<?php echo htmlspecialchars($image_url); ?>" style="cursor: pointer;" onclick="document.getElementById('fileInput').click();" />
                                                                                </span>
                                                                            </div>
                                                                            <input type="file" id="fileInput" style="display: none;" accept="image/*" onchange="previewImage(event)" />
                                                                            <input type="hidden" name="LearnerID" value="<?php echo htmlspecialchars($LearnerID); ?>">
                                                                            <input type="hidden" name="bankID" value="<?php echo htmlspecialchars($learnerData['BankID'] ?? '', ENT_QUOTES, 'UTF-8'); ?>">
                                                                            <input type="hidden" name="classID" value="<?php echo htmlspecialchars($learnerData['classID'] ?? '', ENT_QUOTES, 'UTF-8'); ?>">
                                                                            <div class="col-sm-10">
                                                                                <label class="col-sm-3 col-form-label" for="Title">Title</label>
                                                                                <input type="text" class="form-control col-sm-9" id="Title" name="Title" value="<?php echo htmlspecialchars($learnerData['Title'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" required>
                                                                            </div>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="learnerName">Name</label>
                                                                            <input type="text" class="form-control" id="learnerName" name="Name" value="<?php echo htmlspecialchars($learnerData['Name'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter learner's name" required>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="learnerSurname">Surname</label>
                                                                            <input type="text" class="form-control" id="learnerSurname" name="Surname" value="<?php echo htmlspecialchars($learnerData['Surname'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter learner's surname" required>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="idNumber">ID Number</label>
                                                                            <input type="text" class="form-control" id="idNumber" name="IDNumber" value="<?php echo htmlspecialchars($learnerData['IDNumber'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter your ID number" required>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="learnerContact">Contact Number</label>
                                                                            <input type="text" class="form-control" id="learnerContact" name="PhoneNumber" value="<?php echo htmlspecialchars($learnerData['PhoneNumber'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter learner's contact number" required>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="learnerGender">Gender</label>
                                                                            <input type="text" class="form-control" id="learnerGender" name="Gender" value="<?php echo htmlspecialchars($learnerData['Gender'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter learner's Gender" required>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="learnerAddressLine1">Residential Address Line 1 <span class="address-hint">Street</span></label>
                                                                            <input type="text" class="form-control" id="learnerAddressLine1" name="AddressLine1" value="<?php echo htmlspecialchars($learnerData['AddressLine1'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter street name" required>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="learnerAddressLine2">Residential Address Line 2 <span class="address-hint">Suburb</span></label>
                                                                            <input type="text" class="form-control" id="learnerAddressLine2" name="AddressLine2" value="<?php echo htmlspecialchars($learnerData['AddressLine2'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter suburb" required>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="learnerAddressLine3">Residential Address Line 3 <span class="address-hint">City/Town</span></label>
                                                                            <input type="text" class="form-control" id="learnerAddressLine3" name="AddressLine3" value="<?php echo htmlspecialchars($learnerData['AddressLine3'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter city or town" required>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="learnerPostalCode">Postal Code <span class="address-hint">ZIP/Postcode</span></label>
                                                                            <input type="text" class="form-control" id="learnerPostalCode" name="PostalCode" value="<?php echo htmlspecialchars($learnerData['PostalCode'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter postal code" required>
                                                                        </div>
                                                                    </div>
                                                                </div>
                                                                <div class="col-lg-6">
                                                                    <div class="container border p-3 mb-3">
                                                                        <h5>High School Details</h5>
                                                                        <div class="form-group">
                                                                            <label for="schoolName">School Name</label>
                                                                            <input type="text" class="form-control" id="schoolName" name="SchoolName" value="<?php echo htmlspecialchars($learnerData['SchoolName'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter school name" required>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="completion">Year of Completion</label>
                                                                            <input type="text" class="form-control" id="completion" name="SchoolCompletion" value="<?php echo htmlspecialchars($learnerData['SchoolCompletion'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter Year of completion" required>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="schoolLocation">School Location</label>
                                                                            <input type="text" class="form-control" id="schoolLocation" name="SchoolLocation" value="<?php echo htmlspecialchars($learnerData['SchoolLocation'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter school location" required>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="schoolGrade">Grade</label>
                                                                            <input type="text" class="form-control" id="schoolGrade" name="SchoolGrade" value="<?php echo htmlspecialchars($learnerData['SchoolGrade'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter Highest grade passed" required>
                                                                        </div>
                                                                    </div>
                                                                    <div class="container border p-3 mb-3">
                                                                        <h5>Next of Kin Details</h5>
                                                                        <div class="form-group">
                                                                            <label for="kinName">Name</label>
                                                                            <input type="text" class="form-control" id="kinName" name="KinName" value="<?php echo htmlspecialchars($learnerData['KinName'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter next of kin's name" required>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="kinRelation">Relation</label>
                                                                            <input type="text" class="form-control" id="kinRelation" name="KinRelation" value="<?php echo htmlspecialchars($learnerData['KinRelation'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter relation" required>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="kinContact">Contact Number</label>
                                                                            <input type="text" class="form-control" id="kinContact" name="KinContact" value="<?php echo htmlspecialchars($learnerData['KinContact'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter contact number" required>
                                                                        </div>
                                                                    </div>
                                                                    <div class="container border p-3 mb-3">
                                                                        <h5>Bank Details</h5>
                                                                        <div class="form-group">
                                                                            <label for="bankName">Bank Name</label>
                                                                            <?php if (!empty($learnerData['BankName'])): ?>
                                                                                <input type="text" class="form-control" id="bankName" name="BankName" value="<?php echo htmlspecialchars($learnerData['BankName'], ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter bank name" required>
                                                                            <?php else: ?>
                                                                                <select class="form-control" name="BankName" id="bankName" required>
                                                                                    <option value="">-- Select a Bank --</option>
                                                                                    <option value="Absa Bank">Absa Bank</option>
                                                                                    <option value="Capitec Bank">Capitec Bank</option>
                                                                                    <option value="FNB">First National Bank (FNB)</option>
                                                                                    <option value="Nedbank">Nedbank</option>
                                                                                    <option value="Standard Bank">Standard Bank</option>
                                                                                    <option value="Investec">Investec</option>
                                                                                    <option value="African Bank">African Bank</option>
                                                                                    <option value="TymeBank">TymeBank</option>
                                                                                    <option value="Discovery Bank">Discovery Bank</option>
                                                                                </select>
                                                                            <?php endif; ?>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="bankType">Bank Type</label>
                                                                            <input type="text" class="form-control" id="bankType" name="bankType" value="<?php echo htmlspecialchars($learnerData['bankType'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter bank type" required>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="accountNumber">Account Number</label>
                                                                            <input type="text" class="form-control" id="accountNumber" name="BankAccount" value="<?php echo htmlspecialchars($learnerData['BankAccount'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter account number" required>
                                                                        </div>
                                                                        <div class="form-group">
                                                                            <label for="branchCode">Branch Code</label>
                                                                            <input type="text" class="form-control" id="branchCode" name="BankCode" value="<?php echo htmlspecialchars($learnerData['BankCode'] ?? '', ENT_QUOTES, 'UTF-8'); ?>" placeholder="Enter branch code" required>
                                                                        </div>
                                                                    </div>
                                                                </div>
                                                            </div>
                                                            <div class="container mt-5">
                                                                <div class="d-flex justify-content-between">
                                                                    <button type="submit" class="btn btn-primary">Update</button>
                                                                    <a href="cancel.php" class="btn btn-secondary">Cancel</a>
                                                                </div>
                                                            </div>
                                                        </form>
                                                        <script>
                                                        function validateForm() {
                                                            const inputs = document.querySelectorAll('#learnerForm input[required]');
                                                            let isValid = true;
                                                            inputs.forEach(input => {
                                                                if (input.value.trim() === '') {
                                                                    isValid = false;
                                                                    input.classList.add('is-invalid');
                                                                    alert(`Field "${input.name}" is required.`);
                                                                } else {
                                                                    input.classList.remove('is-invalid');
                                                                }
                                                            });
                                                            return isValid;
                                                        }

                                                        function previewImage(event) {
                                                            const file = event.target.files[0];
                                                            if (file) {
                                                                const reader = new FileReader();
                                                                reader.onload = function(e) {
                                                                    document.getElementById('avatar2').src = e.target.result;
                                                                };
                                                                reader.readAsDataURL(file);
                                                            }
                                                        }
                                                        </script>
                                                    <?php
                                                    } else {
                                                        echo "No data available for the specified LearnerID.";
                                                    }
                                                    ?>
                                                </div>
                                                <!-- Tab 2: Documents -->
                                                <div class="tab-pane fade" id="learner-tab2" role="tabpanel" aria-labelledby="learner-tab2-tab">
                                                    <div id="pictures" class="tab-pane">
                                                        <ul class="ace-thumbnails">
                                                            <div class="container mt-4">
                                                                <button type="button" class="btn btn-primary" data-toggle="modal" data-target="#myModal">
                                                                    Add Learner Document
                                                                </button>
                                                                <!-- Modal -->
                                                                <div class="modal fade" id="myModal" tabindex="-1" role="dialog" aria-labelledby="myModalLabel" aria-hidden="true">
                                                                    <div class="modal-dialog" role="document">
                                                                        <div class="modal-content">
                                                                            <div class="modal-header">
                                                                                <h4 class="modal-title" id="myModalLabel">Select Document and Upload Document</h4>
                                                                                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                                                                                    <span aria-hidden="true">×</span>
                                                                                </button>
                                                                            </div>
                                                                            <div class="modal-body">
                                                                                <form id="documentUploadForm" enctype="multipart/form-data">
                                                                                    <div class="form-group">
                                                                                        <label for="name">Select Name:</label>
                                                                                        <select class="form-control" required id="name" name="documentName" onchange="toggleOtherField()">
                                                                                            <option value="">Select Document</option>
                                                                                            <option value="ID Document">ID Document (compulsory)</option>
                                                                                            <option value="Qualifications">Qualifications (compulsory)</option>
                                                                                            <option value="Learner Agreement">Learner Agreement (compulsory)</option>
                                                                                            <option value="Proof of Residence">Proof of Residence (compulsory)</option>
                                                                                            <option value="CV">Curriculumn Vitae (compulsory)</option>
                                                                                            <option value="Bank Confirmation Letter">Bank Confirmation Letter (compulsory)</option>
                                                                                            <option value="Affidavit/Proof of Experience">Affidavit/Proof of Experience</option>
                                                                                            <option value="Confirmation Letter">Confirmation Letter</option>
                                                                                            <option value="Other">Other</option>
                                                                                        </select>
                                                                                        <div id="otherDocumentField" style="display: none;">
                                                                                            <label for="otherDocumentType" class="mt-2">Select Document Type:</label>
                                                                                            <select class="form-control" id="otherDocumentType" name="otherDocumentType" onchange="toggleCustomNameField()">
                                                                                                <option value="">-- Select Type --</option>
                                                                                                <option value="LMIS Registration">LMIS Registration</option>
                                                                                                <option value="Business Form">Business Form</option>
                                                                                                <option value="POE">POE</option>
                                                                                                <option value="Custom">Custom (Enter Name)</option>
                                                                                            </select>
                                                                                            <div id="customNameField" style="display: none; margin-top: 10px;">
                                                                                                <label for="otherDocumentName">Please specify the document name:</label>
                                                                                                <input type="text" class="form-control" id="otherDocumentName" name="otherDocumentName" placeholder="Enter document name" oninput="updateDropdown()">
                                                                                            </div>
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="form-group">
                                                                                        <input type="hidden" name="LearnerID" value="<?php echo htmlspecialchars($LearnerID); ?>">
                                                                                        <input type="hidden" id="uploadedFileName" name="uploadedFileName">
                                                                                    </div>
                                                                                    <div class="form-group">
                                                                                        <label for="document">Upload Document: <span class="text-muted" id="fileTypeHint">(PDF only, max 30MB)</span></label>
                                                                                        <div class="custom-file-input-wrapper">
                                                                                            <input type="file" class="form-control-file"  id="document" name="learner_document" accept="application/pdf" required>
                                                                                            <div class="custom-file-input-display" id="fileInputDisplay">
                                                                                                <span id="fileNameDisplay">No file chosen</span>
                                                                                                <button type="button" class="btn btn-outline-secondary btn-sm" id="chooseFileButton">Choose File</button>
                                                                                            </div>
                                                                                            <div class="progress" id="uploadProgress">
                                                                                                <div class="progress-bar" role="progressbar" style="width: 0%;" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100" id="progressBar">0%</div>
                                                                                            </div>
                                                                                        </div>
                                                                                    </div>
                                                                                    <button type="submit" class="btn btn-primary" id="submitButton" disabled>Submit</button>
                                                                                </form>
                                                                                <div id="uploadStatus" class="mt-3"></div>
                                                                            </div>
                                                                            <div class="modal-footer">
                                                                                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                                                                            </div>
                                                                        </div>
                                                                    </div>
                                                                </div>
                                                                <!-- Document Table -->
                                                               <table class="table table-striped mt-4">.
                                                               
    <thead>
        <tr>
            <th>Document Type</th>
            <th>Status</th>
            <th>Upload Date</th>
            <th>Action</th>
        </tr>
    </thead>
    <tbody>
        <?php
        if (isset($_GET['LearnerID'])) {
            $LearnerID = $_GET['LearnerID'];

            // Query documents for the learner, prioritizing approved status and removing duplicates
            $sql = "SELECT ld1.* FROM learner_document ld1
                    INNER JOIN (
                        SELECT documentName,
                               MIN(CASE 
                                   WHEN LOWER(TRIM(status)) = 'approved' THEN 1
                                   WHEN LOWER(TRIM(status)) = 'verified' THEN 2
                                   WHEN LOWER(TRIM(status)) = 'pending' THEN 3
                                   WHEN LOWER(TRIM(status)) = 'declined' THEN 4
                                   ELSE 5
                               END) as priority_order,
                               MAX(upload_date) as latest_upload
                        FROM learner_document 
                        WHERE learner_id = ?
                        GROUP BY documentName
                    ) ld2 ON ld1.documentName = ld2.documentName 
                           AND ld1.learner_id = ?
                           AND CASE 
                               WHEN LOWER(TRIM(ld1.status)) = 'approved' THEN 1
                               WHEN LOWER(TRIM(ld1.status)) = 'verified' THEN 2
                               WHEN LOWER(TRIM(ld1.status)) = 'pending' THEN 3
                               WHEN LOWER(TRIM(ld1.status)) = 'declined' THEN 4
                               ELSE 5
                           END = ld2.priority_order
                    ORDER BY ld1.documentName";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("ss", $LearnerID, $LearnerID);
            $stmt->execute();
            $result = $stmt->get_result();

            // Check for Learner Agreement
            $agreementSql = "SELECT * FROM learner_document WHERE learner_id = ? AND documentName = 'Learner Agreement'";
            $agreementStmt = $conn->prepare($agreementSql);
            $agreementStmt->bind_param("s", $LearnerID);
            $agreementStmt->execute();
            $agreementResult = $agreementStmt->get_result();
            $hasAgreement = $agreementResult->num_rows > 0;
            $agreementRow = $agreementResult->fetch_assoc();

            if ($result->num_rows > 0) {
                while ($row = $result->fetch_assoc()) {
                    $statusClass = '';
                    $statusText = trim($row["status"] ?? '');
                    // Debug: Log raw status value (optional, remove in production)
                    error_log("Raw status for document {$row['documentName']}: " . ($row["status"] ?? 'NULL'));

                    if (empty($statusText)) {
                        $statusClass = 'text-secondary';
                        $statusText = 'Not Set';
                    } else {
                        switch (strtolower($statusText)) {
                            case 'verified':
                                $statusClass = 'text-verified';
                                break;
                            case 'approved':
                                $statusClass = 'text-approved';
                                break;
                            case 'declined':
                                $statusClass = 'text-declined';
                                break;
                            case 'pending':
                                $statusClass = 'text-pending';
                                break;
                            default:
                                $statusClass = 'text-secondary';
                                $statusText = 'Unknown';
                        }
                    }
                    echo "<tr>";
                    echo "<td>" . htmlspecialchars($row["documentName"], ENT_QUOTES, 'UTF-8') . "</td>";
                    echo "<td class='$statusClass'>" . htmlspecialchars($statusText, ENT_QUOTES, 'UTF-8') . "</td>";
                    echo "<td>" . htmlspecialchars($row["upload_date"], ENT_QUOTES, 'UTF-8') . "</td>";
                    echo "<td>";
                    echo "<a href='open_document.php?document_id=" . urlencode($row["document_id"]) . "' class='btn btn-primary btn-sm'>Open Document</a>";
                    if (strtolower($row["status"]) === 'declined') {
                        echo "<br><span class='text-danger'>" . htmlspecialchars($row["documentName"], ENT_QUOTES, 'UTF-8') . " declined.<br> Please re-upload a valid document.</span>";
                    }
                    echo "</td>";
                    echo "</tr>";
                }
            } else {
                echo "<tr><td colspan='4'>No records found</td></tr>";
            }
        } else {
            echo "<tr><td colspan='4'>Invalid request</td></tr>";
        }
        ?>
    </tbody>
</table>
                                                           <!----table end  --->
                                                            </div>
                                                        </ul>
                                                    </div>
                                                </div>
                                                <!-- Tab 3: POE -->
                                                <div class="tab-pane fade" id="learner-tab3" role="tabpanel" aria-labelledby="learner-tab3-tab">
                                                    <div class="form-group row align-items-center">
                                                        <div class="col-sm-2 text-center">
                                                            <img src="../assets/img/avatar6.png" alt="Profile Image 3" class="rounded-circle img-fluid" style="width: 50px; height: 50px;">
                                                        </div>
                                                        <div class="col-sm-10">
                                                            <label class="col-sm-3 col-form-label" for="profile3">Title</label>
                                                            <input type="text" class="form-control col-sm-9" id="profile3" name="profile3" placeholder="Enter title 3">
                                                        </div>
                                                    </div>
                                                </div>
                                                <!-- Tab 4: Report -->
                                                <div class="tab-pane fade" id="learner-tab4" role="tabpanel" aria-labelledby="learner-tab4-tab">
                                                    <h3>Reports</h3>
                                                    <?php include 'sdp_learnerView_report.php'; ?>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Scripts -->
    <script src="https://code.jquery.com/jquery-3.5.1.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/@popperjs/core@2.5.4/dist/umd/popper.min.js"></script>
    <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/js/bootstrap.min.js"></script>
    <script src="../assets/vendors/js/vendor.bundle.base.js"></script>
    <script src="../assets/js/off-canvas.js"></script>
    <script src="../assets/js/misc.js"></script>
    <script src="../assets/js/settings.js"></script>
    <script src="../assets/js/todolist.js"></script>
    <script src="../assets/js/jquery.cookie.js"></script>
  <script>
$(document).ready(function () {
    // Initialize primary and nested tabs
    $('.learner-tabs .nav-tabs a, .month-tabs .nav-tabs a').on('click', function (e) {
        e.preventDefault();
        $(this).tab('show');
    });

    // "Choose File" button triggers hidden input
    $('#chooseFileButton').on('click', function () {
        $('#document').click();
    });

    // File input change handler
    $('#document').on('change', function () {
        const fileInput = this;
        const file = fileInput.files[0];
        const progressBar = $('#progressBar');
        const submitButton = $('#submitButton');
        const uploadStatus = $('#uploadStatus');
        const fileNameDisplay = $('#fileNameDisplay');
        const uploadProgress = $('#uploadProgress');

        // Reset UI
        progressBar.css('width', '0%').text('0%');
        uploadProgress.hide();
        submitButton.prop('disabled', true);
        uploadStatus.empty();
        $('#uploadedFileName').val('');
        fileNameDisplay.text('No file chosen');

        if (!file) {
            uploadStatus.html('<div class="alert alert-danger">Please select a file to upload.</div>');
            return;
        }

        // File name display
        fileNameDisplay.text(file.name);

        // Validate file extension
        const documentType = $('#name').val();
        console.log('DEBUG: Document type:', documentType); // Temporary debug
        let allowedExtensions = ['pdf'];
        
        if (documentType === 'Other') {
            // Allow PDF and image files for "Other" documents
            allowedExtensions = ['pdf', 'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'];
            console.log('DEBUG: Other selected, allowing images'); // Temporary debug
        }
        
        const fileExtension = file.name.split('.').pop().toLowerCase();
        console.log('DEBUG: File extension:', fileExtension, 'Allowed:', allowedExtensions); // Temporary debug
        
        if (!allowedExtensions.includes(fileExtension)) {
            console.log('DEBUG: File validation failed'); // Temporary debug
            if (documentType === 'Other') {
                uploadStatus.html('<div class="alert alert-danger">For "Other" documents, only PDF and image files (PNG, JPG, JPEG, GIF, BMP, WEBP) are allowed.</div>');
            } else {
                uploadStatus.html('<div class="alert alert-danger">Only PDF files are allowed.</div>');
            }
            fileInput.value = '';
            return;
        }

        // Validate file size (20MB limit)
        if (file.size > 20 * 1024 * 1024) {
            uploadStatus.html('<div class="alert alert-danger">File size exceeds 20MB limit.</div>');
            fileInput.value = '';
            return;
        }

        uploadProgress.show();

        const formData = new FormData();
        formData.append('learner_document', file);
        formData.append('documentType', documentType); // Pass document type to backend
        
        console.log('DEBUG: Sending documentType:', documentType); // Debug log

        const xhr = new XMLHttpRequest();
        xhr.upload.addEventListener('progress', function (event) {
            if (event.lengthComputable) {
                const percentComplete = Math.round((event.loaded / event.total) * 100);
                progressBar.css('width', percentComplete + '%').text(percentComplete + '%');
                if (percentComplete === 100) {
                    submitButton.prop('disabled', false);
                }
            }
        });

        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                uploadProgress.hide();
                if (xhr.status === 200) {
                    try {
                        const response = JSON.parse(xhr.responseText);
                        console.log('DEBUG: Server response:', response); // Debug log
                        if (response.success) {
                            $('#uploadedFileName').val(response.fileName);
                            uploadStatus.html('<div class="alert alert-success">File uploaded successfully. Please submit to save.</div>');
                        } else {
                            uploadStatus.html(`<div class="alert alert-danger">Error: ${response.error}</div>`);
                            submitButton.prop('disabled', true);
                        }
                    } catch (e) {
                        uploadStatus.html('<div class="alert alert-danger">Invalid server response.</div>');
                        submitButton.prop('disabled', true);
                    }
                } else {
                    uploadStatus.html('<div class="alert alert-danger">An error occurred during the upload. Please try again.</div>');
                    submitButton.prop('disabled', true);
                }
            }
        };

        xhr.open('POST', 'upload_temp_document.php', true);
        xhr.send(formData);
    });

    // Form submission
    $('#documentUploadForm').on('submit', function (e) {
        e.preventDefault();

        const uploadStatus = $('#uploadStatus');
        const documentName = $('#name').val();
        const otherDocumentName = $('#otherDocumentName').val();
        const uploadedFileName = $('#uploadedFileName').val();
        const uploadProgress = $('#uploadProgress');
        const form = this;

        if (!documentName) {
            uploadStatus.html('<div class="alert alert-danger">Please select a document name.</div>');
            return;
        }

        if (documentName === 'Other' && !otherDocumentName) {
            uploadStatus.html('<div class="alert alert-danger">Please specify the document name for "Other".</div>');
            return;
        }

        if (!uploadedFileName) {
            uploadStatus.html('<div class="alert alert-danger">Please upload a valid file before submitting.</div>');
            return;
        }

        // Additional file type validation for form submission
        const fileInput = document.getElementById('document');
        const selectedFile = fileInput.files[0];
        
        if (selectedFile) {
            const fileName = selectedFile.name.toLowerCase();
            
            if (documentName === 'Other') {
                // Allow PDF and common image formats for "Other"
                const allowedExtensions = ['.pdf', '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'];
                const isValidFile = allowedExtensions.some(ext => fileName.endsWith(ext));
                
                if (!isValidFile) {
                    uploadStatus.html('<div class="alert alert-danger">For "Other" documents, please upload a PDF or image file (PNG, JPG, JPEG, GIF, BMP, WEBP).</div>');
                    return;
                }
            } else {
                // Only PDF for standard document types
                if (!fileName.endsWith('.pdf')) {
                    uploadStatus.html('<div class="alert alert-danger">Please upload a PDF file for this document type.</div>');
                    return;
                }
            }
        }

        const formData = new FormData(form);
        formData.append('uploadedFileName', uploadedFileName);

        $.ajax({
            url: 'learnerDocument.php',
            type: 'POST',
            data: formData,
            contentType: false,
            processData: false,
            dataType: 'json',
            success: function (response) {
                if (response.success) {
                    uploadStatus.html(`<div class="alert alert-success">${response.message}</div>`);
                    form.reset();
                    $('#name').val('');
                    $('#otherDocumentName').val('');
                    $('#otherDocumentField').hide();
                    // Reset the "Other" option text back to original
                    const otherOption = document.querySelector('#name option[value="Other"]');
                    if (otherOption) {
                        otherOption.text = 'Other';
                    }
                    $('#fileNameDisplay').text('No file chosen');
                    $('#uploadedFileName').val('');
                    $('#progressBar').css('width', '0%').text('0%');
                    uploadProgress.hide();
                    $('#submitButton').prop('disabled', true);

                    // Close modal and reload page
                    setTimeout(() => {
                        $('#myModal').modal('hide');
                        location.reload();
                    }, 2000);
                } else {
                    uploadStatus.html(`<div class="alert alert-danger">Error: ${response.error}</div>`);
                }
            },
            error: function () {
                uploadStatus.html('<div class="alert alert-danger">An error occurred during submission. Please try again.</div>');
                uploadProgress.hide();
            }
        });
    });
});

// Utility functions
function goBack() {
    window.history.back();
}

function toggleOtherField() {
    const documentDropdown = document.getElementById('name').value;
    const otherField = document.getElementById('otherDocumentField');
    const fileInput = document.getElementById('document');
    const fileTypeHint = document.getElementById('fileTypeHint');
    
    if (documentDropdown === 'Other') {
        otherField.style.display = 'block';
        // Allow both PDF and image files for "Other" documents
        fileInput.accept = 'application/pdf,image/*,.png,.jpg,.jpeg,.gif,.bmp,.webp';
        fileTypeHint.textContent = '(PDF or Image files, max 30MB)';
    } else {
        otherField.style.display = 'none';
        // Reset the other document type dropdown and custom name field
        document.getElementById('otherDocumentType').value = '';
        document.getElementById('customNameField').style.display = 'none';
        document.getElementById('otherDocumentName').value = '';
        // Only PDF for standard document types
        fileInput.accept = 'application/pdf';
        fileTypeHint.textContent = '(PDF only, max 30MB)';
    }
}

function toggleCustomNameField() {
    const otherDocumentType = document.getElementById('otherDocumentType').value;
    const customNameField = document.getElementById('customNameField');
    const otherDocumentName = document.getElementById('otherDocumentName');
    
    if (otherDocumentType === 'Custom') {
        customNameField.style.display = 'block';
        otherDocumentName.value = '';
    } else {
        customNameField.style.display = 'none';
        // Set the document name to the selected type
        if (otherDocumentType) {
            otherDocumentName.value = otherDocumentType;
        } else {
            otherDocumentName.value = '';
        }
    }
}

function updateDropdown() {
    const otherInput = document.getElementById('otherDocumentName').value;
    const documentDropdown = document.getElementById('name');
    
    // Don't change the dropdown text - this was causing the issue
    // The dropdown should always show "Other" as the display text
    // The actual document name will be handled by the backend using otherDocumentName field
}
</script>

</body>
</html>

<?php
$conn->close();
?>

<?php include('sdp_footer.php'); ?>