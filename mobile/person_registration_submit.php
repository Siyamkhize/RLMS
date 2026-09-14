<?php
/**
 * Person Registration Submission Handler
 * Saves registration data to CSV file (can be opened in Excel)
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Only allow POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

try {
    // Get JSON data
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    if (!$data) {
        throw new Exception('Invalid JSON data');
    }
    
    // Validate required fields
    $requiredFields = [
        'title', 'firstName', 'surname', 'idNo', 'dateOfBirth',
        'gender', 'equity', 'nationality', 'cellPhoneNumber',
        'email', 'popiActStatus'
    ];
    
    foreach ($requiredFields as $field) {
        if (empty($data[$field])) {
            throw new Exception("Required field missing: $field");
        }
    }
    
    // Generate unique registration ID
    $registrationId = 'REG-' . date('Ymd') . '-' . strtoupper(substr(md5(uniqid(rand(), true)), 0, 8));
    
    // Prepare CSV file
    $csvFile = __DIR__ . '/person_registrations.csv';
    $isNewFile = !file_exists($csvFile);
    
    // Open file for appending
    $fp = fopen($csvFile, 'a');
    
    if (!$fp) {
        throw new Exception('Failed to open registrations file');
    }
    
    // Write headers if new file
    if ($isNewFile) {
        $headers = [
            'Title', 'FirstName', 'MiddleName', 'Surname', 'MaidenName', 'Initials',
            'IDNo', 'AlternateIDType', 'DateofBirth', 'Gender', 'Equity', 'HighestEducation',
            'CurrentOccupation', 'YearsInOccupation', 'Experience', 'Disability', 'HomeLanguage',
            'Nationality', 'CitizenResidentialStatus', 'CommunicationMethod', 'PersonStatus',
            'SocioEconomicStatus', 'StatusEffectiveDate', 'StatusReason', 'TelephoneNumber',
            'CellPhoneNumber', 'FaxNumber', 'EMail', 'PhysicalAddressLine1', 'PhysicalAddressLine2',
            'PhysicalAddressLine3', 'PhysicalCode', 'PhysicalMunicipality', 'PhysicalUrbanRural',
            'PhysicalProvince', 'PostalAddressLine1', 'PostalAddressLine2', 'PostalAddressLine3',
            'PostalCode', 'PostalMunicipality', 'PostalUrbanRural', 'PostalProvince',
            'ProviderSDLNumber', 'LastSchoolEmis', 'SchoolYear', 'STATSSAAreaCode',
            'POPIActStatus', 'POPIActStatusDate', 'SubmissionTimestamp', 'RegistrationID'
        ];
        fputcsv($fp, $headers);
    }
    
    // Prepare row data matching template structure
    $rowData = [
        $data['title'] ?? '',
        $data['firstName'] ?? '',
        $data['middleName'] ?? '',
        $data['surname'] ?? '',
        $data['maidenName'] ?? '',
        $data['initials'] ?? '',
        $data['idNo'] ?? '',
        $data['alternateIDType'] ?? '',
        $data['dateOfBirth'] ?? '',
        $data['gender'] ?? '',
        $data['equity'] ?? '',
        $data['highestEducation'] ?? '',
        $data['currentOccupation'] ?? '',
        $data['yearsInOccupation'] ?? '',
        $data['experience'] ?? '',
        $data['disability'] ?? '',
        $data['homeLanguage'] ?? '',
        $data['nationality'] ?? '',
        $data['citizenResidentialStatus'] ?? '',
        $data['communicationMethod'] ?? '',
        $data['personStatus'] ?? '',
        $data['socioEconomicStatus'] ?? '',
        $data['statusEffectiveDate'] ?? '',
        $data['statusReason'] ?? '',
        $data['telephoneNumber'] ?? '',
        $data['cellPhoneNumber'] ?? '',
        $data['faxNumber'] ?? '',
        $data['email'] ?? '',
        $data['physicalAddressLine1'] ?? '',
        $data['physicalAddressLine2'] ?? '',
        $data['physicalAddressLine3'] ?? '',
        $data['physicalCode'] ?? '',
        $data['physicalMunicipality'] ?? '',
        $data['physicalUrbanRural'] ?? '',
        $data['physicalProvince'] ?? '',
        $data['postalAddressLine1'] ?? '',
        $data['postalAddressLine2'] ?? '',
        $data['postalAddressLine3'] ?? '',
        $data['postalCode'] ?? '',
        $data['postalMunicipality'] ?? '',
        $data['postalUrbanRural'] ?? '',
        $data['postalProvince'] ?? '',
        $data['providerSDLNumber'] ?? '',
        $data['lastSchoolEmis'] ?? '',
        $data['schoolYear'] ?? '',
        $data['statsSAAreaCode'] ?? '',
        $data['popiActStatus'] ?? '',
        $data['popiActStatusDate'] ?? '',
        date('Y-m-d H:i:s'),
        $registrationId
    ];
    
    // Write data row
    fputcsv($fp, $rowData);
    fclose($fp);
    
    // Log the registration
    $logEntry = date('Y-m-d H:i:s') . " | {$registrationId} | {$data['firstName']} {$data['surname']} | {$data['email']}\n";
    file_put_contents(__DIR__ . '/registrations.log', $logEntry, FILE_APPEND);
    
    // Count total registrations
    $lines = file($csvFile);
    $totalRegistrations = count($lines) - 1; // Exclude header
    
    // Send success response
    echo json_encode([
        'success' => true,
        'message' => 'Registration submitted successfully',
        'id' => $registrationId,
        'total' => $totalRegistrations,
        'timestamp' => date('Y-m-d H:i:s')
    ]);
    
} catch (Exception $e) {
    // Log error
    $errorLog = date('Y-m-d H:i:s') . " ERROR: " . $e->getMessage() . "\n";
    file_put_contents(__DIR__ . '/registration_errors.log', $errorLog, FILE_APPEND);
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
