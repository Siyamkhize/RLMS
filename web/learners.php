<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ARPL Portfolio Generator - Select Learners</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="assets/css/arpl_style.css">
    <style>
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container-main {
            max-width: 1200px;
            margin: 0 auto;
        }
        .card {
            border: none;
            border-radius: 15px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.3);
            margin-bottom: 20px;
        }
        .card-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border-radius: 15px 15px 0 0;
            padding: 25px;
        }
        .card-body {
            padding: 30px;
        }
        .step-indicator {
            background: rgba(255,255,255,0.2);
            padding: 8px 15px;
            border-radius: 20px;
            display: inline-block;
            font-size: 12px;
            font-weight: 600;
            color: white;
            margin-bottom: 15px;
        }
        .learner-table {
            width: 100%;
            border-collapse: collapse;
        }
        .learner-table thead {
            background: #f8f9fa;
        }
        .learner-table th {
            padding: 12px;
            text-align: left;
            font-weight: 600;
            border-bottom: 2px solid #e9ecef;
        }
        .learner-table td {
            padding: 12px;
            border-bottom: 1px solid #e9ecef;
        }
        .learner-table tbody tr:hover {
            background: #f8f9fa;
        }
        .btn-generate {
            background: linear-gradient(135deg, #28a745 0%, #20c997 100%);
            color: white;
            border: none;
            padding: 6px 15px;
            border-radius: 5px;
            font-size: 12px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            text-decoration: none;
            display: inline-block;
        }
        .btn-generate:hover {
            color: white;
            transform: scale(1.05);
            text-decoration: none;
        }
        .status-badge {
            display: inline-block;
            padding: 4px 10px;
            border-radius: 20px;
            font-size: 11px;
            font-weight: 600;
        }
        .status-enrolled {
            background: #d4edda;
            color: #155724;
        }
        .status-completed {
            background: #cce5ff;
            color: #004085;
        }
        .loading {
            text-align: center;
            padding: 40px;
            color: #6c757d;
        }
        .spinner {
            display: inline-block;
            width: 40px;
            height: 40px;
            border: 4px solid #f3f3f3;
            border-top: 4px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .btn-group-bottom {
            margin-top: 20px;
            display: flex;
            gap: 10px;
        }
        .btn-back {
            background: #e9ecef;
            color: #333;
            border: none;
            padding: 12px 30px;
            font-weight: 600;
            border-radius: 8px;
        }
        .btn-back:hover {
            background: #dee2e6;
            color: #333;
        }
        .breadcrumb {
            background: #f8f9fa;
            padding: 10px 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            font-size: 13px;
        }
        .breadcrumb span {
            margin: 0 5px;
        }
        .error-message {
            background: #f8d7da;
            border: 1px solid #f5c6cb;
            color: #721c24;
            padding: 15px;
            border-radius: 8px;
            margin-top: 20px;
        }
        .learner-count {
            background: #e7f3ff;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            color: #004085;
        }
    </style>
</head>
<body>
    <div class="container-main">
        <!-- Navigation Card -->
        <div class="card">
            <div class="card-header">
                <div class="step-indicator">STEP 3 OF 3: SELECT & GENERATE</div>
                <h1 class="mb-2 mt-2">Generate ARPL Portfolios</h1>
                <p class="mb-0 text-white-50">Select learners and generate their ARPL documentation</p>
            </div>
            <div class="card-body">
                <!-- Breadcrumb -->
                <div class="breadcrumb">
                    <span class="badge bg-primary" id="tradeBadge">Trade</span>
                    <span>→</span>
                    <span class="badge bg-success" id="classBadge">Class</span>
                </div>
                
                <!-- Learner Count -->
                <div class="learner-count">
                    <strong id="countText">Loading learners...</strong>
                </div>
                
                <!-- Learners Table -->
                <div id="learnersContainer" class="loading">
                    <div class="spinner"></div>
                    <p style="margin-top: 15px;">Loading learners...</p>
                </div>
                
                <!-- Error Message -->
                <div id="errorMessage" style="display: none;"></div>
                
                <!-- Buttons -->
                <div class="btn-group-bottom">
                    <button class="btn-back" onclick="goBack()">← Back to Classes</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Modal for PDF generation -->
    <div id="generateModal" style="display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 999; align-items: center; justify-content: center; flex-direction: column;">
        <div style="background: white; padding: 30px; border-radius: 10px; text-align: center; max-width: 400px;">
            <h3 style="margin-bottom: 20px;">Generating ARPL Portfolio</h3>
            <div class="spinner" style="margin: 20px auto;"></div>
            <p id="generatingText">Please wait while we generate the ARPL portfolio...</p>
            <p style="font-size: 12px; color: #6c757d; margin-top: 15px;">This may take a moment</p>
        </div>
    </div>

    <script>
        let selectedTradeOFO = sessionStorage.getItem('selectedTradeOFO');
        let selectedClassID = sessionStorage.getItem('selectedClassID');
        let userClickedButton = false; // Safety flag to prevent auto-generation
        
        const tradeNames = {
            '671101': 'Electrician',
            '641201': 'Bricklaying',
            '642601': 'Plumbing',
            '651302': 'Welding'
        };

        document.addEventListener('DOMContentLoaded', function() {
            console.log('🔷 learners.php DOMContentLoaded');
            console.log('selectedTradeOFO:', selectedTradeOFO);
            console.log('selectedClassID:', selectedClassID);
            
            if (!selectedTradeOFO || !selectedClassID) {
                console.error('❌ Missing trade or class selection');
                showError('Missing trade or class selection. Please start over.');
                return;
            }
            
            document.getElementById('tradeBadge').textContent = 'Trade: ' + (tradeNames[selectedTradeOFO] || 'Unknown');
            document.getElementById('classBadge').textContent = 'Class ID: ' + selectedClassID;
            
            console.log('✅ About to load learners...');
            loadLearners();
        });

        function loadLearners() {
            const requestData = {
                classID: parseInt(selectedClassID)
            };
            
            console.log('📥 loadLearners: Fetching learners for classID=' + selectedClassID);
            
            fetch('api/get_arpl_class_learners.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(requestData)
            })
            .then(response => {
                console.log('📡 API response status:', response.status);
                return response.json();
            })
            .then(data => {
                console.log('📊 API response data:', data);
                if (data.status === 'success') {
                    console.log('✅ Received ' + data.learners.length + ' learners from API');
                    displayLearners(data.learners);
                } else {
                    console.error('❌ API error:', data.message);
                    showError(data.message || 'Failed to load learners');
                }
            })
            .catch(error => {
                console.error('❌ Network error:', error);
                showError('Network error: ' + error.message);
            });
        }

        function displayLearners(learners) {
            const container = document.getElementById('learnersContainer');
            
            if (learners.length === 0) {
                container.innerHTML = '<p class="text-muted">No learners found in this class.</p>';
                document.getElementById('countText').textContent = '0 learners found';
                return;
            }
            
            document.getElementById('countText').textContent = learners.length + ' learner' + (learners.length !== 1 ? 's' : '') + ' found';
            
            let html = `
                <table class="learner-table">
                    <thead>
                        <tr>
                            <th>Learner ID</th>
                            <th>Name</th>
                            <th>ID Number</th>
                            <th>Gender</th>
                            <th>Status</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody>
            `;
            
            learners.forEach(learner => {
                const statusClass = learner.status === 'Completed' ? 'status-completed' : 'status-enrolled';
                html += `
                    <tr>
                        <td>${learner.learnerID}</td>
                        <td>${learner.learnerName}</td>
                        <td>${learner.idNumber || 'N/A'}</td>
                        <td>${learner.gender || 'N/A'}</td>
                        <td><span class="status-badge ${statusClass}">${learner.status}</span></td>
                        <td>
                            <button class="btn-generate" onclick="handleGenerateClick(${learner.learnerID}, '${learner.learnerName.replace(/'/g, "\\'")}')">
                                Generate ARPL ▶
                            </button>
                        </td>
                    </tr>
                `;
            });
            
            html += `
                    </tbody>
                </table>
            `;
            
            container.innerHTML = html;
            console.log('📊 Displayed ' + learners.length + ' learners with individual buttons');
            document.getElementById('errorMessage').style.display = 'none';
        }
        
        function handleGenerateClick(learnerID, learnerName) {
            console.log('🔘 Generate button clicked for learnerID=' + learnerID + ', learnerName=' + learnerName);
            userClickedButton = true;
            generateARPL(learnerID, learnerName);
        }

        function generateARPL(learnerID, learnerName) {
            console.log('🔶 generateARPL called with learnerID=' + learnerID + ', learnerName=' + learnerName);
            console.log('userClickedButton flag:', userClickedButton);
            
            // Safety check: ensure user actually clicked a button
            if (!userClickedButton) {
                console.error('❌ SECURITY: generateARPL called without user clicking button! Blocking...');
                alert('Error: Please click a button to generate ARPL.');
                return;
            }
            
            if (!confirm('Generate ARPL portfolio for ' + learnerName + '?\n\nThis will create a PDF document with all assessment data and supporting documents.')) {
                console.log('❌ User cancelled generation');
                return;
            }
            
            console.log('✅ User confirmed. Showing modal and preparing to redirect...');
            
            // Show generating modal
            const modal = document.getElementById('generateModal');
            modal.style.display = 'flex';
            document.getElementById('generatingText').textContent = 'Generating portfolio for ' + learnerName + '...';
            
            // For now, navigate to a placeholder PDF generation page
            // In production, this would call a PDF generation endpoint
            console.log('🔵 About to redirect to generate_pdf.php with learnerID=' + learnerID + '&ofo_code=' + selectedTradeOFO);
            setTimeout(() => {
                const url = 'generate_pdf.php?learnerID=' + learnerID + '&ofo_code=' + selectedTradeOFO;
                console.log('🟢 Redirecting to:', url);
                window.location.href = url;
            }, 500);
        }

        function goBack() {
            window.location.href = 'classes.php';
        }

        function showError(message) {
            const errorDiv = document.getElementById('errorMessage');
            errorDiv.innerHTML = '<div class="error-message">' + message + '</div>';
            errorDiv.style.display = 'block';
            document.getElementById('learnersContainer').innerHTML = '';
        }
    </script>
</body>
</html>
