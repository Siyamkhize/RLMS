<?php
/**
 * Populate ARPL v3 tables for learner 16389
 * Creates application, work experience, references, and qualifications data
 */

require_once 'connection.php';
date_default_timezone_set('Africa/Johannesburg');

$learnerID = 16389;
$learner = $conn->query("SELECT * FROM learnerdetails WHERE LearnerID = $learnerID")->fetch_assoc();

if (!$learner) {
    die("Learner $learnerID not found!\n");
}

echo "Starting ARPL v3 data population for learner: " . $learner['Name'] . " " . $learner['Surname'] . "\n";
echo "ID Number: " . ($learner['IDNumber'] ?? 'N/A') . "\n\n";

// ═══════════════════════════════════════════════════════════════════════
// STEP 1: Create Application
// ═══════════════════════════════════════════════════════════════════════

$dob = isset($learner['DateOfBirth']) ? date('Y-m-d', strtotime($learner['DateOfBirth'])) : '1989-02-08';
$gender = $learner['Gender'] ?? 'Male';
$phone = $learner['PhoneNumber'] ?? '0790131055';
$email = $learner['EmailAddress'] ?? 'lungisani.cele@example.com';

// Prepare address parts
$address1 = $learner['AddressLine1'] ?? '123 Main Street';
$city = $learner['AddressLine2'] ?? 'Johannesburg';
$postal = $learner['PostalCode'] ?? '2000';

// Map gender
$gender_mapped = 'Male';
if (strtolower($gender) === 'female' || $gender === 'F') {
    $gender_mapped = 'Female';
}

// Create application
$sql = "INSERT INTO arpl_applications_v3 (
    id_number, first_name, last_name, date_of_birth, gender, email, phone,
    street_address, city, postal_code, province,
    trade_applied_for, total_years_of_experience,
    highest_qualification, qualification_level,
    has_cv, has_id_copy, has_qualification_cert, has_proof_of_address,
    meets_requirements, eligibility_status, application_status,
    application_date, submission_date, created_at, updated_at,
    registration_step, is_complete, learning_pathway
) VALUES (
    '" . $conn->real_escape_string($learner['IDNumber']) . "',
    '" . $conn->real_escape_string($learner['Name']) . "',
    '" . $conn->real_escape_string($learner['Surname']) . "',
    '$dob',
    '$gender_mapped',
    '" . $conn->real_escape_string($email) . "',
    '" . $conn->real_escape_string($phone) . "',
    '" . $conn->real_escape_string($address1) . "',
    '" . $conn->real_escape_string($city) . "',
    '" . $conn->real_escape_string($postal) . "',
    'Gauteng',
    'Plumbing',
    15,
    'Grade 12',
    'Secondary',
    1, 1, 1, 1,
    1, 'Eligible', 'Submitted',
    CURDATE(), CURDATE(), NOW(), NOW(),
    5, 1, 'Plumbing - Full Programme'
)";

if ($conn->query($sql)) {
    $application_id = $conn->insert_id;
    echo "✓ Created application record (ID: $application_id)\n";
} else {
    die("Error creating application: " . $conn->error . "\n");
}

// ═══════════════════════════════════════════════════════════════════════
// STEP 2: Add Work Experience (3 entries)
// ═══════════════════════════════════════════════════════════════════════

$work_experiences = [
    [
        'employer' => 'Plumbing Solutions (Pty) Ltd',
        'job_title' => 'Plumber',
        'type' => 'Employed',
        'start' => '2019-01-15',
        'end' => NULL,
        'current' => 1,
        'years' => 5,
        'months' => 6,
        'duties' => 'Installation and maintenance of plumbing systems, pipe fitting, bathroom renovations, leak repairs, drainage system design and implementation'
    ],
    [
        'employer' => 'Master Plumbers Inc',
        'job_title' => 'Apprentice Plumber',
        'type' => 'Employed',
        'start' => '2015-06-01',
        'end' => '2018-12-31',
        'current' => 0,
        'years' => 3,
        'months' => 7,
        'duties' => 'Assisted senior plumbers with installations, learned pipe welding, hot water systems, studied technical plumbing theory'
    ],
    [
        'employer' => 'Self-Employed',
        'job_title' => 'Plumbing Contractor',
        'type' => 'Self-Employed',
        'start' => '2009-03-01',
        'end' => '2015-05-31',
        'current' => 0,
        'years' => 6,
        'months' => 3,
        'duties' => 'Residential and commercial plumbing projects, customer service, small team management, emergency plumbing repairs'
    ]
];

foreach ($work_experiences as $exp) {
    $end_date = $exp['end'] ? "'" . $exp['end'] . "'" : 'NULL';
    $sql = "INSERT INTO arpl_work_experience_v3 (
        application_id, employer_name, job_title, employment_type,
        start_date, end_date, is_current_job, years_worked, months_worked,
        duties_description, created_at
    ) VALUES (
        $application_id,
        '" . $conn->real_escape_string($exp['employer']) . "',
        '" . $conn->real_escape_string($exp['job_title']) . "',
        '" . $exp['type'] . "',
        '" . $exp['start'] . "',
        $end_date,
        " . $exp['current'] . ",
        " . $exp['years'] . ",
        " . $exp['months'] . ",
        '" . $conn->real_escape_string($exp['duties']) . "',
        NOW()
    )";
    
    if ($conn->query($sql)) {
        echo "  ✓ Added work experience: " . $exp['employer'] . " - " . $exp['job_title'] . "\n";
    } else {
        echo "  ✗ Error adding work experience: " . $conn->error . "\n";
    }
}

// ═══════════════════════════════════════════════════════════════════════
// STEP 3: Add References (3 entries)
// ═══════════════════════════════════════════════════════════════════════

$references = [
    [
        'name' => 'John',
        'surname' => 'Mthembu',
        'phone' => '0113456789',
        'email' => 'john.mthembu@plumbing.co.za',
        'company' => 'Plumbing Solutions (Pty) Ltd',
        'position' => 'Senior Plumber & Supervisor',
        'type' => 'Supervisor',
        'order' => 1
    ],
    [
        'name' => 'Sarah',
        'surname' => 'Johnson',
        'phone' => '0821234567',
        'email' => 'sarah.johnson@masterplumbers.com',
        'company' => 'Master Plumbers Inc',
        'position' => 'Training Coordinator',
        'type' => 'Manager',
        'order' => 2
    ],
    [
        'name' => 'Robert',
        'surname' => 'Dlamini',
        'phone' => '0723456789',
        'email' => 'robert.d@emailprovider.com',
        'company' => 'Residential Clients Network',
        'position' => 'Regular Client',
        'type' => 'Client',
        'order' => 3
    ]
];

foreach ($references as $ref) {
    $sql = "INSERT INTO arpl_references_v3 (
        application_id, reference_name, reference_surname, reference_phone,
        reference_email, company_name, job_position, contact_type, reference_order, created_at
    ) VALUES (
        $application_id,
        '" . $conn->real_escape_string($ref['name']) . "',
        '" . $conn->real_escape_string($ref['surname']) . "',
        '" . $conn->real_escape_string($ref['phone']) . "',
        '" . $conn->real_escape_string($ref['email']) . "',
        '" . $conn->real_escape_string($ref['company']) . "',
        '" . $conn->real_escape_string($ref['position']) . "',
        '" . $ref['type'] . "',
        " . $ref['order'] . ",
        NOW()
    )";
    
    if ($conn->query($sql)) {
        echo "  ✓ Added reference: " . $ref['name'] . " " . $ref['surname'] . " (" . $ref['type'] . ")\n";
    } else {
        echo "  ✗ Error adding reference: " . $conn->error . "\n";
    }
}

// ═══════════════════════════════════════════════════════════════════════
// STEP 4: Add Qualifications (3 entries)
// ═══════════════════════════════════════════════════════════════════════

$qualifications = [
    [
        'name' => 'Grade 12 (Matric)',
        'level' => 'Secondary',
        'institution' => 'Central High School, Johannesburg',
        'year' => 2008,
        'cert_num' => 'GR12-2008-JNB-001',
        'is_primary' => 1
    ],
    [
        'name' => 'Plumbing NQF Level 3',
        'level' => 'Technical',
        'institution' => 'City Skills Development Centre',
        'year' => 2015,
        'cert_num' => 'NQF3-PLUMB-2015-CSC',
        'is_primary' => 0
    ],
    [
        'name' => 'Pipe Welding Certification',
        'level' => 'Occupational',
        'institution' => 'Advanced Welding Academy',
        'year' => 2016,
        'cert_num' => 'WELD-CERT-2016-AWA',
        'is_primary' => 0
    ]
];

foreach ($qualifications as $qual) {
    $sql = "INSERT INTO arpl_qualifications_v3 (
        application_id, qualification_name, qualification_level, institution_name,
        year_obtained, certificate_number, is_primary, created_at
    ) VALUES (
        $application_id,
        '" . $conn->real_escape_string($qual['name']) . "',
        '" . $conn->real_escape_string($qual['level']) . "',
        '" . $conn->real_escape_string($qual['institution']) . "',
        " . $qual['year'] . ",
        '" . $conn->real_escape_string($qual['cert_num']) . "',
        " . $qual['is_primary'] . ",
        NOW()
    )";
    
    if ($conn->query($sql)) {
        echo "  ✓ Added qualification: " . $qual['name'] . " (" . $qual['year'] . ")\n";
    } else {
        echo "  ✗ Error adding qualification: " . $conn->error . "\n";
    }
}

// ═══════════════════════════════════════════════════════════════════════
// STEP 5: Verify all data
// ═══════════════════════════════════════════════════════════════════════

echo "\n=== VERIFICATION ===\n\n";

// Verify application
$app_check = $conn->query("SELECT * FROM arpl_applications_v3 WHERE id = $application_id")->fetch_assoc();
if ($app_check) {
    echo "✓ Application verified (ID: $application_id)\n";
    echo "  Name: " . $app_check['first_name'] . " " . $app_check['last_name'] . "\n";
    echo "  Trade: " . $app_check['trade_applied_for'] . "\n";
    echo "  Status: " . $app_check['application_status'] . "\n";
}

// Verify work experience
$work_count = $conn->query("SELECT COUNT(*) as cnt FROM arpl_work_experience_v3 WHERE application_id = $application_id")->fetch_assoc()['cnt'];
echo "✓ Work experience records: $work_count\n";

// Verify references
$ref_count = $conn->query("SELECT COUNT(*) as cnt FROM arpl_references_v3 WHERE application_id = $application_id")->fetch_assoc()['cnt'];
echo "✓ Reference records: $ref_count\n";

// Verify qualifications
$qual_count = $conn->query("SELECT COUNT(*) as cnt FROM arpl_qualifications_v3 WHERE application_id = $application_id")->fetch_assoc()['cnt'];
echo "✓ Qualification records: $qual_count\n";

echo "\n=== COMPLETE ===\n";
echo "All ARPL v3 data has been populated for learner 16389!\n";
echo "Application ID: $application_id\n";

$conn->close();
?>
