<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header('Content-Type: application/json');

include('connection.php');

try {
    // Get all active materials from inventory
    $sql = "SELECT 
                inventory_id,
                material_name,
                material_code,
                category,
                unit_of_measure,
                current_stock,
                minimum_stock,
                maximum_stock,
                unit_cost,
                supplier,
                description,
                status
            FROM material_inventory 
            WHERE status = 'Active' 
            ORDER BY category, material_name";

    $result = $conn->query($sql);
    
    if ($result === false) {
        throw new Exception("Query failed: " . $conn->error);
    }

    $materials = [];
    while ($row = $result->fetch_assoc()) {
        $materials[] = [
            'inventory_id' => (string)$row['inventory_id'],
            'material_name' => $row['material_name'] ?? '',
            'material_code' => $row['material_code'] ?? '',
            'category' => $row['category'] ?? '',
            'unit_of_measure' => $row['unit_of_measure'] ?? 'pieces',
            'current_stock' => (int)($row['current_stock'] ?? 0),
            'minimum_stock' => (int)($row['minimum_stock'] ?? 0),
            'maximum_stock' => (int)($row['maximum_stock'] ?? 0),
            'unit_cost' => (float)($row['unit_cost'] ?? 0.00),
            'supplier' => $row['supplier'] ?? '',
            'description' => $row['description'] ?? '',
            'status' => $row['status'] ?? 'Active',
            'stock_status' => (int)($row['current_stock'] ?? 0) <= (int)($row['minimum_stock'] ?? 0) ? 'Low Stock' : 'Available'
        ];
    }

    echo json_encode([
        'success' => true,
        'materials' => $materials,
        'total_materials' => count($materials)
    ]);

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}

$conn->close();
?>