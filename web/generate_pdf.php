<?php
// Initialize connection early - before any output
// Try multiple paths for connection file
$connection_paths = [
    __DIR__ . '/connection.php',           // Same directory
    __DIR__ . '/../connection.php',        // One level up
    __DIR__ . '/../../connection.php',     // Two levels up
    'C:/xampp/htdocs/web/web/web/connection.php',
    '../../../connection.php'
];

$conn = null;
foreach ($connection_paths as $path) {
    if (file_exists($path)) {
        include $path;
        break;
    }
}

if (!$conn) {
    die('<div style="color: red; padding: 20px;"><h2>❌ Connection Error</h2><p>Could not find connection.php in any expected location.</p></div>');
}

$conn->set_charset("utf8mb4");
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ARPL Portfolio PDF Generator</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
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
        }
        .card-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border-radius: 15px 15px 0 0;
            padding: 30px;
        }
        .card-body {
            padding: 40px;
        }
        .success-icon {
            font-size: 60px;
            text-align: center;
            margin-bottom: 20px;
        }
        .info-box {
            background: #f0f4ff;
            border: 1px solid #667eea;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
        }
        .document-structure {
            background: white;
            border: 1px solid #e9ecef;
            border-radius: 10px;
            padding: 20px;
            margin: 20px 0;
        }
        .doc-section {
            padding: 10px 0;
            border-bottom: 1px solid #e9ecef;
        }
        .doc-section:last-child {
            border-bottom: none;
        }
        .doc-number {
            display: inline-block;
            background: #667eea;
            color: white;
            width: 30px;
            height: 30px;
            border-radius: 50%;
            text-align: center;
            line-height: 30px;
            font-weight: 600;
            margin-right: 10px;
            font-size: 12px;
        }
        .btn-group {
            display: flex;
            gap: 10px;
            margin-top: 30px;
        }
        .btn {
            flex: 1;
            padding: 12px;
            font-weight: 600;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        .btn-primary {
            background: linear-gradient(135deg, #28a745 0%, #20c997 100%);
            color: white;
        }
        .btn-primary:hover {
            transform: scale(1.02);
            color: white;
        }
        .btn-secondary {
            background: #e9ecef;
            color: #333;
        }
        .btn-secondary:hover {
            background: #dee2e6;
            color: #333;
        }
        .status {
            text-align: center;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 10px;
            margin: 20px 0;
        }
        .status-text {
            font-size: 14px;
            color: #6c757d;
            margin-top: 10px;
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
        .loading {
            display: none;
            text-align: center;
            padding: 20px;
        }
        .loading.active {
            display: block;
        }
        .success {
            display: none;
        }
        .success.active {
            display: block;
        }
    </style>
</head>
<body>
    <div class="container-main">
        <div class="card">
            <div class="card-header">
                <h1 class="mb-2">ARPL Portfolio PDF Generator</h1>
                <p class="mb-0 text-white-50">Generating complete ARPL documentation</p>
            </div>
            <div class="card-body">
                <?php
                // Get parameters from URL
                $learnerID = isset($_GET['learnerID']) ? intval($_GET['learnerID']) : 0;
                $classID = isset($_GET['classID']) ? intval($_GET['classID']) : 0;
                $ofo_code = isset($_GET['ofo_code']) ? trim($_GET['ofo_code']) : '';
                
                // Try to lookup classID if missing
                $classID_looked_up = false;
                if ($classID <= 0 && $learnerID > 0) {
                    try {
                        $st = $conn->prepare("SELECT classID FROM learnerdetails WHERE LearnerID = ? LIMIT 1");
                        if ($st) {
                            $st->bind_param("i", $learnerID);
                            $st->execute();
                            $result = $st->get_result();
                            if ($row = $result->fetch_assoc()) {
                                $classID = (int)$row['classID'];
                                $classID_looked_up = true;
                            }
                            $st->close();
                        }
                    } catch (Exception $e) {
                        // Silently continue - classID stays 0
                    }
                }
                
                // Validate parameters (show debug info)
                if ($learnerID <= 0 || empty($ofo_code)) {
                    echo '<div class="alert alert-danger">';
                    echo '<strong>❌ Invalid Parameters</strong><br>';
                    echo 'Required: learnerID and ofo_code<br><br>';
                    echo '<small>Debug Info:<br>';
                    echo 'learnerID=' . $learnerID . '<br>';
                    echo 'classID=' . $classID . ' (looked up: ' . ($classID_looked_up ? 'YES' : 'NO') . ')<br>';
                    echo 'ofo_code=' . htmlspecialchars($ofo_code) . '<br>';
                    echo '</small>';
                    echo '</div>';
                    echo '<button class="btn btn-secondary" onclick="window.location.href=\'index.php\'">Go to Home</button>';
                } else {
                    $tradeNames = [
                        '671101' => 'Electrician',
                        '641201' => 'Bricklaying',
                        '642601' => 'Plumbing',
                        '651302' => 'Welding'
                    ];
                    
                    $tradeName = isset($tradeNames[$ofo_code]) ? $tradeNames[$ofo_code] : 'Unknown Trade';
                ?>
                
                <!-- Loading State -->
                <div class="loading active" id="loadingState">
                    <div class="spinner" style="margin: 20px auto;"></div>
                    <h3 style="color: #667eea; margin-top: 20px;">Generating ARPL Portfolio</h3>
                    <p style="color: #6c757d;">Please wait while we generate your 24-page portfolio...</p>
                    <p style="font-size: 12px; color: #999; margin-top: 15px;">This may take a moment</p>
                </div>
                
                <!-- Success State -->
                <div class="success" id="successState">
                    <div class="success-icon">✅</div>
                    <h2 style="text-align: center; color: #667eea;">ARPL Portfolio v3 Generated Successfully</h2>
                    
                    <div class="status">
                        <strong>Trade:</strong> <span id="tradeName"><?php echo htmlspecialchars($tradeName); ?></span> (<?php echo htmlspecialchars($ofo_code); ?>)<br>
                        <strong>Learner ID:</strong> <span id="learnerDisplay"><?php echo $learnerID; ?></span><br>
                        <strong>Portfolio Pages:</strong> 30+<br>
                        <strong>Format:</strong> Exact Mobile App Replica<br>
                        <strong>Generated:</strong> <span id="generatedDate"></span>
                    </div>
                    
                    <div class="info-box">
                        <h5>📋 ARPL Portfolio v3 (30+ Pages) - Exact Mobile App Format</h5>
                        <p>Your professional portfolio includes:</p>
                    </div>
                    
                    <div class="document-structure">
                        <div class="doc-section">
                            <span class="doc-number">1</span>
                            <strong>Cover Page</strong>
                            <div style="font-size: 12px; color: #6c757d; margin-left: 40px;">✅ DHET branding, watermark, trade information</div>
                        </div>
                        <div class="doc-section">
                            <span class="doc-number">2</span>
                            <strong>Contents & Index</strong>
                            <div style="font-size: 12px; color: #6c757d; margin-left: 40px;">✅ Complete page reference guide</div>
                        </div>
                        <div class="doc-section">
                            <span class="doc-number">3</span>
                            <strong>Appendix A: Application Form</strong>
                            <div style="font-size: 12px; color: #6c757d; margin-left: 40px;">✅ Learner details, employment history, signatures</div>
                        </div>
                        <div class="doc-section">
                            <span class="doc-number">4</span>
                            <strong>Competency Proficiency Scale</strong>
                            <div style="font-size: 12px; color: #6c757d; margin-left: 40px;">📊 Reference: Fundamental to Expert (1-5)</div>
                        </div>
                        <div class="doc-section">
                            <span class="doc-number">5</span>
                            <strong>Appendix B: Self-Evaluation Checklist</strong>
                            <div style="font-size: 12px; color: #6c757d; margin-left: 40px;">✅ Activities rated 1-5, assessor verification</div>
                        </div>
                        <div class="doc-section">
                            <span class="doc-number">6</span>
                            <strong>Appendix C: Trade Curriculum Content</strong>
                            <div style="font-size: 12px; color: #6c757d; margin-left: 40px;">📚 Curriculum standards & requirements</div>
                        </div>
                        <div class="doc-section">
                            <span class="doc-number">7</span>
                            <strong>Appendix D: Practical Skills Assessment</strong>
                            <div style="font-size: 12px; color: #6c757d; margin-left: 40px;">✅ Trade-specific practical criteria (15+ items)</div>
                        </div>
                        <div class="doc-section">
                            <span class="doc-number">8</span>
                            <strong>Appendix E: Workplace Experience Evaluation</strong>
                            <div style="font-size: 12px; color: #6c757d; margin-left: 40px;">✅ Activities rated 1-5, witness verification</div>
                        </div>
                        <div class="doc-section">
                            <span class="doc-number">9</span>
                            <strong>Appendix F: Assessment Evaluation Agreement</strong>
                            <div style="font-size: 12px; color: #6c757d; margin-left: 40px;">📋 Assessment terms & conditions</div>
                        </div>
                        <div class="doc-section">
                            <span class="doc-number">10</span>
                            <strong>Appendix G: Appeals Form</strong>
                            <div style="font-size: 12px; color: #6c757d; margin-left: 40px;">📝 Appeal procedures & contact details</div>
                        </div>
                        <div class="doc-section">
                            <span class="doc-number">11</span>
                            <strong>Appendix H: Access Recommendation</strong>
                            <div style="font-size: 12px; color: #6c757d; margin-left: 40px;">✅ Assessor recommendation section</div>
                        </div>
                        <div class="doc-section">
                            <span class="doc-number">12</span>
                            <strong>Appendix I: Statement of Results</strong>
                            <div style="font-size: 12px; color: #6c757d; margin-left: 40px;">🎓 Final results & competency statement</div>
                        </div>
                        <div class="doc-section">
                            <span class="doc-number">13</span>
                            <strong>Appendix J: Pre-Assessment Agreement</strong>
                            <div style="font-size: 12px; color: #6c757d; margin-left: 40px;">✅ Candidate pre-assessment consent</div>
                        </div>
                    </div>
                    
                    <div class="info-box" style="background: #d4edda; border: 1px solid #c3e6cb;">
                        <h5 style="color: #155724;">✅ ARPL PDF v3 Implementation Complete</h5>
                        <ul style="margin-bottom: 0; color: #155724;">
                            <li>✅ Exact mobile app format replica</li>
                            <li>✅ All 11 appendices with complete content</li>
                            <li>✅ Trade-specific practical criteria (Electrician, Bricklaying, Plumbing)</li>
                            <li>✅ Professional styling & print-optimized layout</li>
                            <li>✅ Database-integrated with prefilled learner data</li>
                            <li>✅ Ready for assessor review and PDF export</li>
                        </ul>
                    </div>
                    
                    <div class="btn-group">
                        <button class="btn btn-secondary" onclick="printPortfolio()">🖨️ Print PDF</button>
                        <button class="btn btn-secondary" onclick="window.location.href='learners.php'">← Back to Learners</button>
                        <button class="btn btn-primary" onclick="downloadPortfolio()">⬇️ Download ARPL</button>
                        <button class="btn btn-secondary" onclick="window.location.href='index.php'">← Home</button>
                    </div>
                </div>
                
                <!-- Error State -->
                <div id="errorState" style="display: none;">
                    <div class="alert alert-danger">
                        <h4>Error Generating Portfolio</h4>
                        <p id="errorMessage"></p>
                    </div>
                    <div class="btn-group">
                        <button class="btn btn-secondary" onclick="window.location.href='learners.php'">← Back to Learners</button>
                        <button class="btn btn-secondary" onclick="location.reload()">🔄 Retry</button>
                    </div>
                </div>
                
                <script>
                    const learnerID = <?php echo $learnerID; ?>;
                    const ofo_code = '<?php echo $ofo_code; ?>';
                    
                    // Start PDF generation when page loads
                    document.addEventListener('DOMContentLoaded', function() {
                        console.log('🔷 PDF generation page loaded for learnerID=' + learnerID);
                        generatePDF();
                    });
                    
                    function generatePDF() {
                        console.log('📄 Starting PDF generation...');
                        
                        const learnerID = <?php echo $learnerID; ?>;
                        const classID = <?php echo $classID; ?>;
                        const ofo_code = '<?php echo htmlspecialchars($ofo_code ?? '671101'); ?>';
                        
                        console.log('📨 Parameters:', {learnerID, classID, ofo_code});
                        
                        // Redirect to unified PDF generator using relative path
                        const url = `arpl_pdf.php?learnerID=${learnerID}&classID=${classID}&ofo_code=${ofo_code}`;
                        console.log('🔗 Redirecting to:', url);
                        window.location.href = url;
                    }
                    
                    function openGeneratedPDF() {
                        console.log('🔷 Opening generated PDF in new window...');
                        if (window.generatedHTML) {
                            const w = window.open();
                            w.document.write(window.generatedHTML);
                            w.document.close();
                        }
                    }
                    
                    function showSuccess(filename) {
                        console.log('✅ PDF generated successfully');
                        document.getElementById('loadingState').classList.remove('active');
                        document.getElementById('successState').classList.add('active');
                        document.getElementById('generatedDate').textContent = new Date().toLocaleString();
                        window.generatedFile = filename;
                    }
                    
                    function showError(message) {
                        console.log('❌ Error:', message);
                        document.getElementById('loadingState').classList.remove('active');
                        document.getElementById('errorState').style.display = 'block';
                        document.getElementById('errorMessage').textContent = message;
                    }
                    
                    function printPortfolio() {
                        console.log('🖨️ Opening print dialog...');
                        window.print();
                    }
                    
                    function downloadPortfolio() {
                        console.log('⬇️ Downloading portfolio as HTML...');
                        if (window.generatedFile) {
                            window.location.href = 'pdfs/' + window.generatedFile;
                        } else {
                            alert('Portfolio not yet generated. Please wait.');
                        }
                    }
                </script>
                
                <?php
                }
                ?>
            </div>
        </div>
    </div>
</body>
</html>
