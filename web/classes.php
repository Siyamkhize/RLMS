<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ARPL Portfolio Generator - Select Class</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="assets/css/arpl_style.css">
    <style>
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container-main {
            max-width: 1000px;
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
        .breadcrumb {
            background: #f8f9fa;
            padding: 10px 15px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        .class-item {
            background: white;
            border: 1px solid #e9ecef;
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 10px;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        .class-item:hover {
            border-color: #667eea;
            box-shadow: 0 3px 10px rgba(102, 126, 234, 0.2);
            transform: translateX(5px);
        }
        .class-item.active {
            background: #f0f4ff;
            border-color: #667eea;
            color: #667eea;
        }
        .class-name {
            font-weight: 600;
            margin-bottom: 5px;
        }
        .class-details {
            font-size: 12px;
            color: #6c757d;
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
        .btn-back, .btn-continue {
            flex: 1;
            padding: 12px;
            font-weight: 600;
            border-radius: 8px;
            border: none;
        }
        .btn-back {
            background: #e9ecef;
            color: #333;
        }
        .btn-back:hover {
            background: #dee2e6;
            color: #333;
        }
        .btn-continue {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .btn-continue:hover {
            color: white;
            transform: scale(1.02);
        }
        .btn-continue:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }
        .error-message {
            background: #f8d7da;
            border: 1px solid #f5c6cb;
            color: #721c24;
            padding: 15px;
            border-radius: 8px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container-main">
        <!-- Navigation Card -->
        <div class="card">
            <div class="card-header">
                <div class="step-indicator">STEP 2 OF 3: SELECT CLASS</div>
                <h1 class="mb-2 mt-2">Select a Class</h1>
                <p class="mb-0 text-white-50">Choose the class to view learners for ARPL generation</p>
            </div>
            <div class="card-body">
                <!-- Breadcrumb -->
                <div class="breadcrumb">
                    <span class="badge bg-primary" id="tradeBadge">Loading trade...</span>
                </div>
                
                <!-- Classes List -->
                <div id="classesList" class="loading">
                    <div class="spinner"></div>
                    <p style="margin-top: 15px;">Loading classes...</p>
                </div>
                
                <!-- Error Message -->
                <div id="errorMessage" style="display: none;"></div>
                
                <!-- Buttons -->
                <div class="btn-group-bottom">
                    <button class="btn-back" onclick="goBack()">← Back to Trade</button>
                    <button class="btn-continue" id="btnContinue" onclick="goToLearners()" disabled>
                        View Learners →
                    </button>
                </div>
            </div>
        </div>
    </div>

    <script>
        let selectedClass = null;
        let selectedTradeOFO = sessionStorage.getItem('selectedTradeOFO');
        
        // Trade name mapping
        const tradeNames = {
            '671101': 'Electrician',
            '641201': 'Bricklaying',
            '642601': 'Plumbing',
            '651302': 'Welding'
        };

        // Initialize button state
        document.addEventListener('DOMContentLoaded', function() {
            console.log('DOM loaded, initializing...');
            const btn = document.getElementById('btnContinue');
            if (btn) btn.disabled = true;
            
            if (!selectedTradeOFO) {
                showError('No trade selected. Please start over.');
                return;
            }
            
            document.getElementById('tradeBadge').textContent = 'Trade: ' + (tradeNames[selectedTradeOFO] || 'Unknown');
            loadClasses();
            
            // Setup event delegation for class items
            setupEventDelegation();
        });
        
        function setupEventDelegation() {
            const container = document.getElementById('classesList');
            if(container) {
                container.addEventListener('click', function(e) {
                    const classItem = e.target.closest('.class-item');
                    if(classItem) {
                        const classID = classItem.getAttribute('data-class-id');
                        console.log('Class item clicked via event delegation! classID=' + classID);
                        selectClass(classItem, parseInt(classID));
                    }
                });
            }
        }

        function loadClasses() {
            const requestData = {
                ofo_code: selectedTradeOFO
            };
            
            console.log('loadClasses: Sending request with ofo_code=' + selectedTradeOFO);
            
            fetch('api/get_arpl_classes.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(requestData)
            })
            .then(response => {
                console.log('API Response status:', response.status);
                return response.json();
            })
            .then(data => {
                console.log('API Response data:', data);
                if (data.status === 'success') {
                    console.log('Success: Found ' + data.classes.length + ' classes');
                    displayClasses(data.classes);
                } else {
                    console.error('API Error:', data.message);
                    showError(data.message || 'Failed to load classes');
                }
            })
            .catch(error => {
                console.error('Network error:', error);
                showError('Network error: ' + error.message);
            });
        }

        function displayClasses(classes) {
            console.log('displayClasses called with ' + classes.length + ' classes');
            const container = document.getElementById('classesList');
            
            if (classes.length === 0) {
                console.warn('No classes found');
                container.innerHTML = '<p class="text-muted text-center">No classes found for this trade.</p>';
                document.getElementById('btnContinue').disabled = true;
                return;
            }
            
            let html = '';
            classes.forEach(cls => {
                console.log('Adding class: ' + cls.className + ' with classID: ' + cls.classID);
                html += '<div class="class-item" data-class-id="' + cls.classID + '">';
                html += '<div class="class-name">' + cls.className + '</div>';
                html += '<div class="class-details"><span>👥 ' + cls.numberOfLearners + ' learners</span></div>';
                html += '</div>';
            });
            
            container.innerHTML = html;
            document.getElementById('errorMessage').style.display = 'none';
            console.log('Classes displayed, HTML inserted');
        }

        function selectClass(element, classID) {
            console.log('selectClass called with classID=' + classID);
            
            // Remove active class from all
            document.querySelectorAll('.class-item').forEach(item => {
                item.classList.remove('active');
            });
            
            // Add active to clicked
            element.classList.add('active');
            selectedClass = classID;
            
            // Enable continue button
            const btn = document.getElementById('btnContinue');
            if (btn) {
                btn.disabled = false;
                console.log('✅ Button ENABLED');
            }
        }

        function goToLearners() {
            if (!selectedClass) {
                alert('Please select a class first');
                return;
            }
            sessionStorage.setItem('selectedClassID', selectedClass);
            window.location.href = 'learners.php';
        }

        function goBack() {
            sessionStorage.clear();
            window.location.href = 'index.php';
        }

        function showError(message) {
            const errorDiv = document.getElementById('errorMessage');
            errorDiv.innerHTML = '<div class="error-message">' + message + '</div>';
            errorDiv.style.display = 'block';
            document.getElementById('classesList').innerHTML = '';
        }
    </script>
</body>
</html>
