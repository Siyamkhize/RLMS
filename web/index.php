<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ARPL Portfolio Generator</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="assets/css/arpl_style.css">
    <style>
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container-main {
            max-width: 1000px;
            width: 100%;
        }
        .card {
            border: none;
            border-radius: 15px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.3);
        }
        .card-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border-radius: 15px 15px 0 0;
            padding: 30px;
            text-align: center;
        }
        .card-body {
            padding: 40px;
        }
        .trade-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        .trade-card {
            background: #f8f9fa;
            border: 2px solid #e9ecef;
            border-radius: 10px;
            padding: 20px;
            text-align: center;
            cursor: pointer;
            transition: all 0.3s ease;
            text-decoration: none;
            color: inherit;
        }
        .trade-card:hover {
            border-color: #667eea;
            transform: translateY(-5px);
            box-shadow: 0 5px 20px rgba(102, 126, 234, 0.3);
        }
        .trade-card.active {
            background: #667eea;
            border-color: #667eea;
            color: white;
        }
        .trade-icon {
            font-size: 48px;
            margin-bottom: 10px;
        }
        .trade-name {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 5px;
        }
        .trade-code {
            font-size: 12px;
            opacity: 0.7;
        }
        .btn-continue {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border: none;
            color: white;
            font-weight: 600;
            padding: 12px 40px;
            border-radius: 8px;
            margin-top: 20px;
        }
        .btn-continue:hover {
            color: white;
            transform: scale(1.05);
        }
        .step-indicator {
            background: #e9ecef;
            padding: 10px 20px;
            border-radius: 20px;
            display: inline-block;
            font-size: 12px;
            font-weight: 600;
            color: #667eea;
            margin-bottom: 20px;
        }
        .info-box {
            background: #f0f4ff;
            border-left: 4px solid #667eea;
            padding: 15px;
            margin-top: 20px;
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <div class="container-main">
        <div class="card">
            <div class="card-header">
                <h1 class="mb-2">ARPL Portfolio Generator</h1>
                <p class="mb-0 text-white-50">Generate complete ARPL documentation for your learners</p>
            </div>
            <div class="card-body">
                <div class="step-indicator">STEP 1 OF 3: SELECT TRADE</div>
                
                <h3 class="mb-4">Choose a Trade</h3>
                <p class="text-muted mb-4">Select the trade for which you want to generate ARPL portfolios:</p>
                
                <div class="trade-grid" id="tradeGrid">
                    <!-- Trades will be loaded here by JavaScript -->
                </div>
                
                <div style="text-align: center;">
                    <button class="btn btn-continue" id="btnContinue" onclick="goToClasses()" disabled>
                        Continue to Classes →
                    </button>
                </div>
                
                <div class="info-box">
                    <strong>ℹ️ How it works:</strong><br>
                    1. Select a trade<br>
                    2. Choose a class under that trade<br>
                    3. Select learners and generate their ARPL portfolios
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        let selectedTrade = null;

        function selectTrade(element) {
            // Remove active class from all cards
            document.querySelectorAll('.trade-card').forEach(card => {
                card.classList.remove('active');
            });
            
            // Add active class to clicked card
            element.classList.add('active');
            
            // Store selected trade
            selectedTrade = element.getAttribute('data-trade');
            
            // Enable continue button
            document.getElementById('btnContinue').disabled = false;
        }

        function goToClasses() {
            if (!selectedTrade) {
                alert('Please select a trade');
                return;
            }
            
            // Store in session storage and navigate
            sessionStorage.setItem('selectedTradeOFO', selectedTrade);
            window.location.href = 'classes.php';
        }

        // Load trades on page load
        document.addEventListener('DOMContentLoaded', function() {
            loadTrades();
        });
        
        function loadTrades() {
            fetch('api/get_arpl_trades.php')
                .then(response => response.json())
                .then(data => {
                    if (data.status === 'success') {
                        displayTrades(data.trades);
                    } else {
                        showError('Failed to load trades: ' + data.message);
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    showError('Network error loading trades');
                });
        }
        
        function displayTrades(trades) {
            const grid = document.getElementById('tradeGrid');
            const icons = {
                'Electrician': '⚡',
                'Bricklayer': '🧱',
                'Plumber': '🔧',
                'Welder': '🔨',
                'default': '⚙️'
            };
            
            let html = '';
            trades.forEach(trade => {
                const icon = icons[trade.trade_name] || icons.default;
                html += `
                    <div class="trade-card" data-trade="${trade.ofo_code}" data-name="${trade.trade_name}" onclick="selectTrade(this)">
                        <div class="trade-icon">${icon}</div>
                        <div class="trade-name">${trade.trade_name}</div>
                        <div class="trade-code">OFO ${trade.ofo_code}</div>
                    </div>
                `;
            });
            grid.innerHTML = html;
        }
        
        function showError(message) {
            console.error('Error:', message);
            const grid = document.getElementById('tradeGrid');
            grid.innerHTML = '<div class="alert alert-danger">' + message + '</div>';
        }
    </script>
</body>
</html>
