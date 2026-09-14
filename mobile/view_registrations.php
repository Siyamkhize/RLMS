<?php
/**
 * View Registrations - Admin Panel
 * Display all person registrations in a table
 */

$csvFile = __DIR__ . '/person_registrations.csv';

// Handle export to Excel
if (isset($_GET['export'])) {
    if (file_exists($csvFile)) {
        header('Content-Type: application/vnd.ms-excel');
        header('Content-Disposition: attachment; filename="person_registrations_' . date('Ymd_His') . '.csv"');
        readfile($csvFile);
        exit;
    }
}

// Read registrations
$registrations = [];
$totalCount = 0;

if (file_exists($csvFile)) {
    $file = fopen($csvFile, 'r');
    $headers = fgetcsv($file); // Get headers
    
    while (($row = fgetcsv($file)) !== FALSE) {
        $registrations[] = array_combine($headers, $row);
        $totalCount++;
    }
    fclose($file);
    
    // Reverse to show newest first
    $registrations = array_reverse($registrations);
}

?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>View Registrations - Admin Panel</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #f5f6fa;
            padding: 20px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            padding: 30px;
        }
        
        h1 {
            color: #333;
            margin-bottom: 10px;
        }
        
        .stats {
            display: flex;
            gap: 20px;
            margin: 20px 0;
            flex-wrap: wrap;
        }
        
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            min-width: 200px;
        }
        
        .stat-card h3 {
            font-size: 14px;
            opacity: 0.9;
            margin-bottom: 5px;
        }
        
        .stat-card .number {
            font-size: 32px;
            font-weight: bold;
        }
        
        .actions {
            margin: 20px 0;
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        
        .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            text-decoration: none;
            display: inline-block;
            transition: all 0.3s;
        }
        
        .btn-primary {
            background: #667eea;
            color: white;
        }
        
        .btn-primary:hover {
            background: #5568d3;
        }
        
        .btn-success {
            background: #28a745;
            color: white;
        }
        
        .btn-success:hover {
            background: #218838;
        }
        
        .search-box {
            margin: 20px 0;
        }
        
        .search-box input {
            padding: 10px;
            width: 100%;
            max-width: 400px;
            border: 2px solid #e0e0e0;
            border-radius: 6px;
            font-size: 14px;
        }
        
        .table-container {
            overflow-x: auto;
            margin-top: 20px;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
        }
        
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #e0e0e0;
        }
        
        th {
            background: #f8f9fa;
            font-weight: 600;
            color: #333;
            position: sticky;
            top: 0;
        }
        
        tr:hover {
            background: #f8f9fa;
        }
        
        .badge {
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
        }
        
        .badge-success {
            background: #d4edda;
            color: #155724;
        }
        
        .badge-warning {
            background: #fff3cd;
            color: #856404;
        }
        
        .badge-danger {
            background: #f8d7da;
            color: #721c24;
        }
        
        .no-data {
            text-align: center;
            padding: 40px;
            color: #666;
        }
        
        .no-data p {
            margin: 10px 0;
        }
        
        @media (max-width: 768px) {
            .container {
                padding: 15px;
            }
            
            table {
                font-size: 12px;
            }
            
            th, td {
                padding: 8px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📋 Person Registrations - Admin Panel</h1>
        <p style="color: #666; margin-bottom: 20px;">View and manage all person registrations</p>
        
        <div class="stats">
            <div class="stat-card">
                <h3>Total Registrations</h3>
                <div class="number"><?php echo $totalCount; ?></div>
            </div>
            <div class="stat-card">
                <h3>Latest Registration</h3>
                <div class="number" style="font-size: 16px;">
                    <?php 
                    if (!empty($registrations)) {
                        echo date('d M Y H:i', strtotime($registrations[0]['SubmissionTimestamp']));
                    } else {
                        echo 'N/A';
                    }
                    ?>
                </div>
            </div>
        </div>
        
        <div class="actions">
            <a href="person_registration_form.html" class="btn btn-primary">➕ New Registration</a>
            <a href="?export=1" class="btn btn-success">📥 Export to Excel</a>
            <a href="?refresh=1" class="btn btn-primary">🔄 Refresh</a>
        </div>
        
        <div class="search-box">
            <input type="text" id="searchInput" placeholder="🔍 Search by name, ID, email..." onkeyup="searchTable()">
        </div>
        
        <div class="table-container">
            <?php if (empty($registrations)): ?>
                <div class="no-data">
                    <h3>📭 No Registrations Yet</h3>
                    <p>No registrations have been submitted yet.</p>
                    <p><a href="person_registration_form.html" class="btn btn-primary" style="margin-top: 20px;">Submit First Registration</a></p>
                </div>
            <?php else: ?>
                <table id="registrationsTable">
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>Registration ID</th>
                            <th>Name</th>
                            <th>ID Number</th>
                            <th>Email</th>
                            <th>Cell Phone</th>
                            <th>Gender</th>
                            <th>Province</th>
                            <th>POPI Status</th>
                            <th>Submitted</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($registrations as $index => $reg): ?>
                        <tr>
                            <td><?php echo $index + 1; ?></td>
                            <td><strong><?php echo htmlspecialchars($reg['RegistrationID']); ?></strong></td>
                            <td><?php echo htmlspecialchars($reg['Title'] . ' ' . $reg['FirstName'] . ' ' . $reg['Surname']); ?></td>
                            <td><?php echo htmlspecialchars($reg['IDNo']); ?></td>
                            <td><?php echo htmlspecialchars($reg['EMail']); ?></td>
                            <td><?php echo htmlspecialchars($reg['CellPhoneNumber']); ?></td>
                            <td><?php echo htmlspecialchars($reg['Gender']); ?></td>
                            <td><?php echo htmlspecialchars($reg['PhysicalProvince']); ?></td>
                            <td>
                                <?php 
                                $status = htmlspecialchars($reg['POPIActStatus']);
                                $badgeClass = $status === 'Accepted' ? 'badge-success' : 
                                             ($status === 'Pending' ? 'badge-warning' : 'badge-danger');
                                ?>
                                <span class="badge <?php echo $badgeClass; ?>"><?php echo $status; ?></span>
                            </td>
                            <td><?php echo date('d M Y H:i', strtotime($reg['SubmissionTimestamp'])); ?></td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            <?php endif; ?>
        </div>
    </div>
    
    <script>
        function searchTable() {
            const input = document.getElementById('searchInput');
            const filter = input.value.toLowerCase();
            const table = document.getElementById('registrationsTable');
            const rows = table.getElementsByTagName('tr');
            
            for (let i = 1; i < rows.length; i++) {
                const row = rows[i];
                const text = row.textContent.toLowerCase();
                
                if (text.includes(filter)) {
                    row.style.display = '';
                } else {
                    row.style.display = 'none';
                }
            }
        }
        
        // Auto-refresh every 30 seconds
        setTimeout(function() {
            location.reload();
        }, 30000);
    </script>
</body>
</html>
