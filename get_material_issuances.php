<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json');

include('connection.php');

try {
    $logistics_id = $_GET['logistics_id'] ?? '';
    $site_id = $_GET['site_id'] ?? '';
    $class_id = $_GET['class_id'] ?? '';
    
    // Build the WHERE clause based on provided parameters
    $whereConditions = [];
    $params = [];
    $types = '';
    
    if (!empty($logistics_id)) {
        $whereConditions[] = "mi.logistics_id = ?";
        $params[] = $logistics_id;
        $types .= 's';
    }
    
    if (!empty($site_id)) {
        $whereConditions[] = "mi.site_id = ?";
        $params[] = $site_id;
        $types .= 's';
    }
    
    if (!empty($class_id)) {
        $whereConditions[] = "mi.class_id = ?";
        $params[] = $class_id;
        $types .= 's';
    }
    
    $whereClause = '';
    if (!empty($whereConditions)) {
        $whereClause = 'WHERE ' . implode(' AND ', $whereConditions);
    }

    // Get material issuances with details
    $sql = "SELECT 
                mi.id,
                mi.logistics_id,
                mi.logistics_name,
                mi.site_id,
                mi.site_name,
                mi.class_id,
                mi.class_name,
                mi.facilitator_id,
                mi.facilitator_name,
                mi.issue_date,
                mi.issue_type,
                mi.unit_standard_id,
                mi.unit_standard_name,
                mi.total_quantity,
                mi.notes,
                mi.status,
                mi.created_at,
                COUNT(DISTINCT mii.id) as total_items,
                COUNT(DISTINCT lmd.id) as distributed_items,
                SUM(mii.quantity_issued) as total_quantity_issued,
                SUM(lmd.quantity_received) as total_quantity_distributed
            FROM material_issuance mi
            LEFT JOIN material_issuance_items mii ON mi.id = mii.issuance_id
            LEFT JOIN learner_material_distribution lmd ON mi.id = lmd.issuance_id
            $whereClause
            GROUP BY mi.id
            ORDER BY mi.issue_date DESC, mi.created_at DESC";

    if (!empty($params)) {
        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            throw new Exception("Prepare failed: " . $conn->error);
        }
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
    } else {
        $result = $conn->query($sql);
        if ($result === false) {
            throw new Exception("Query failed: " . $conn->error);
        }
    }

    $issuances = [];
    while ($row = $result->fetch_assoc()) {
        $issuances[] = [
            'id' => (string)$row['id'],
            'logistics_id' => $row['logistics_id'] ?? '',
            'logistics_name' => $row['logistics_name'] ?? '',
            'site_id' => $row['site_id'] ?? '',
            'site_name' => $row['site_name'] ?? '',
            'class_id' => $row['class_id'] ?? '',
            'class_name' => $row['class_name'] ?? '',
            'facilitator_id' => $row['facilitator_id'] ?? '',
            'facilitator_name' => $row['facilitator_name'] ?? '',
            'issue_date' => $row['issue_date'] ?? '',
            'issue_type' => $row['issue_type'] ?? '',
            'unit_standard_id' => $row['unit_standard_id'] ?? '',
            'unit_standard_name' => $row['unit_standard_name'] ?? '',
            'total_quantity' => (string)($row['total_quantity'] ?? '0'),
            'notes' => $row['notes'] ?? '',
            'status' => $row['status'] ?? 'Issued',
            'created_at' => $row['created_at'] ?? '',
            'total_items' => (string)($row['total_items'] ?? '0'),
            'distributed_items' => (string)($row['distributed_items'] ?? '0'),
            'total_quantity_issued' => (string)($row['total_quantity_issued'] ?? '0'),
            'total_quantity_distributed' => (string)($row['total_quantity_distributed'] ?? '0')
        ];
    }

    echo json_encode([
        'success' => true,
        'issuances' => $issuances,
        'total_issuances' => count($issuances)
    ]);

    if (isset($stmt)) {
        $stmt->close();
    }

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}

$conn->close();
?>