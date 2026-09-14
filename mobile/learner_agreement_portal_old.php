<?php
/**
 * Learner Agreement Portal with OTP Verification
 * Session expires after 24 hours
 */

// Start session
session_start();

// Check if session is still valid (24 hours)
$otp_verified = false;
if (isset($_SESSION['agreement_portal_verified']) && $_SESSION['agreement_portal_verified'] === true) {
    $expiry_time = $_SESSION['agreement_portal_expiry'] ?? 0;
    if (time() < $expiry_time) {
        $otp_verified = true;
        $id_number = $_SESSION['agreement_portal_id'];
    } else {
        // Session expired
        session_destroy();
        session_start();
    }
}

// Handle logout
if (isset($_GET['logout'])) {
    session_destroy();
    header('Location: learner_agreement_portal_otp.php');
    exit;
}

// Include database connection only if verified
if ($otp_verified) {
    ob_start();
    require_once '../connection.php';
    
    error_reporting(E_ALL);
    ini_set('display_errors', 1);
    
    $error_message = '';
    $success_message = '';
    $agreements = [];
    $searched = false;
    
    // Search for agreements
    if ($otp_verified && !empty($id_number)) {
        $searched = true;
        
        // Get learner details
        $learner_stmt = $conn->prepare("
            SELECT 
                ld.LearnerID,
                ld.Name,
                ld.Surname,
                ld.IDNumber,
                ld.PhoneNumber
            FROM learnerdetails ld
            WHERE ld.IDNumber = ?
            LIMIT 1
        ");
        
        if ($learner_stmt) {
            $learner_stmt->bind_param('s', $id_number);
            $learner_stmt->execute();
            $learner_result = $learner_stmt->get_result();
            
            if ($learner_result->num_rows > 0) {
                $learner = $learner_result->fetch_assoc();
                $learner_id = $learner['LearnerID'];
                
                // Get latest agreement
                $stmt = $conn->prepare("
                    SELECT 
                        id,
                        learner_id,
                        learner_name,
                        project_id,
                        document_type,
                        pdf_filename,
                        pdf_path,
                        file_size,
                        generated_date,
                        year,
                        month
                    FROM stored_agreement_pdfs
                    WHERE learner_id = ?
                    AND document_type = 'agreement'
                    ORDER BY year DESC, month DESC, generated_date DESC
                    LIMIT 1
                ");
                
                if ($stmt) {
                    $stmt->bind_param('s', $id_number);
                    $stmt->execute();
                    $result = $stmt->get_result();
                    
                    if ($result->num_rows > 0) {
                        while ($row = $result->fetch_assoc()) {
                            $agreements[] = $row;
                        }
                        $latest = $agreements[0];
                        $period = '';
                        if ($latest['year'] && $latest['month']) {
                            $period = ' (' . date('F Y', mktime(0, 0, 0, $latest['month'], 1, $latest['year'])) . ')';
                        }
                        $success_message = 'Latest agreement found for ' . htmlspecialchars($learner['Name'] . ' ' . $learner['Surname']) . $period;
                    } else {
                        $error_message = 'No learner agreements found. Your agreement may not have been generated yet.';
                    }
                    $stmt->close();
                }
            }
            $learner_stmt->close();
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Secure Learner Agreement Portal</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .container-custom {
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            max-width: 900px;
            width: 100%;
            overflow: hidden;
        }

        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
            position: relative;
        }

        .header h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }

        .header p {
            font-size: 14px;
            opacity: 0.9;
        }

        .logout-btn {
            position: absolute;
            top: 20px;
            right: 20px;
            background: rgba(255,255,255,0.2);
            color: white;
            border: 1px solid white;
            padding: 5px 15px;
            border-radius: 5px;
            text-decoration: none;
            font-size: 14px;
        }

        .logout-btn:hover {
            background: rgba(255,255,255,0.3);
            color: white;
        }

        .content {
            padding: 40px;
        }

        .otp-step {
            display: none;
        }

        .otp-step.active {
            display: block;
        }

        .form-group {
            margin-bottom: 20px;
        }

        .form-group label {
            display: block;
            font-weight: 600;
            margin-bottom: 8px;
            color: #333;
        }

        .form-group input {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
        }

        .form-group input:focus {
            outline: none;
            border-color: #667eea;
        }

        .btn {
            display: inline-block;
            padding: 12px 30px;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
            text-decoration: none;
            text-align: center;
        }

        .btn-primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            width: 100%;
        }

        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }

        .btn-secondary {
            background: #4caf50;
            color: white;
            margin-right: 10px;
        }

        .btn-secondary:hover {
            background: #45a049;
        }

        .btn-info {
            background: #2196F3;
            color: white;
        }

        .btn-info:hover {
            background: #0b7dda;
        }

        .btn-link {
            background: none;
            color: #667eea;
            text-decoration: underline;
            padding: 0;
        }

        .alert {
            padding: 15px 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .alert-error {
            background: #fee;
            color: #c33;
            border-left: 4px solid #c33;
        }

        .alert-success {
            background: #efe;
            color: #3c3;
            border-left: 4px solid #3c3;
        }

        .alert-info {
            background: #e3f2fd;
            color: #1976d2;
            border-left: 4px solid #1976d2;
        }

        .agreement-card {
            background: #f9f9f9;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 15px;
        }

        .agreement-card:hover {
            border-color: #667eea;
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.2);
        }

        .agreement-details {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 15px 0;
        }

        .detail-item {
            display: flex;
            flex-direction: column;
        }

        .detail-label {
            font-size: 12px;
            color: #888;
            margin-bottom: 4px;
        }

        .detail-value {
            font-size: 14px;
            font-weight: 600;
            color: #333;
        }

        .countdown {
            background: #fff3cd;
            border: 1px solid #ffc107;
            padding: 10px;
            border-radius: 5px;
            margin: 15px 0;
            text-align: center;
            color: #856404;
        }

        .otp-input {
            font-size: 24px;
            letter-spacing: 10px;
            text-align: center;
            font-weight: bold;
        }

        @media (max-width: 768px) {
            .content {
                padding: 20px;
            }

            .header h1 {
                font-size: 24px;
            }
        }
    </style>
</head>
<body>
    <div class="container-custom">
        <div class="header">
            <h1>🔐 Secure Agreement Portal</h1>
            <p>OTP-Protected Access to Your Learner Agreements</p>
            <?php if ($otp_verified): ?>
                <a href="?logout=1" class="logout-btn">Logout</a>
            <?php endif; ?>
        </div>

        <div class="content">
            <?php if (!$otp_verified): ?>
                <!-- Step 1: Enter ID Number -->
                <div id="step1" class="otp-step active">
                    <div class="alert alert-info">
                        <span>🔒</span>
                        <span>For security, we'll send a verification code to your registered phone number.</span>
                    </div>

                    <form id="idForm" onsubmit="sendOTP(event)">
                        <div class="form-group">
                            <label for="id_number">South African ID Number</label>
                            <input 
                                type="text" 
                                id="id_number" 
                                name="id_number" 
                                placeholder="Enter your 13-digit ID Number"
                                maxlength="13"
                                pattern="[0-9]{13}"
                                required
                            >
                        </div>
                        <button type="submit" class="btn btn-primary" id="sendOtpBtn">
                            📱 Send Verification Code
                        </button>
                    </form>
                </div>

                <!-- Step 2: Enter OTP -->
                <div id="step2" class="otp-step">
                    <div class="alert alert-success" id="otpSentMessage"></div>

                    <div class="countdown" id="countdown"></div>

                    <form id="otpForm" onsubmit="verifyOTP(event)">
                        <div class="form-group">
                            <label for="otp">Enter 6-Digit Verification Code</label>
                            <input 
                                type="text" 
                                id="otp" 
                                name="otp" 
                                placeholder="000000"
                                maxlength="6"
                                pattern="[0-9]{6}"
                                class="otp-input"
                                required
                            >
                        </div>
                        <button type="submit" class="btn btn-primary" id="verifyOtpBtn">
                            ✅ Verify & Access Agreement
                        </button>
                        <div style="margin-top: 15px; text-align: center;">
                            <button type="button" class="btn-link" onclick="resendOTP()">
                                Didn't receive code? Resend
                            </button>
                        </div>
                    </form>
                </div>

            <?php else: ?>
                <!-- Step 3: Show Agreements (Verified) -->
                <div class="alert alert-success">
                    <span>✅</span>
                    <span>Session verified. Access expires in <?php echo ceil((($_SESSION['agreement_portal_expiry'] ?? 0) - time()) / 3600); ?> hours.</span>
                </div>

                <?php if ($error_message): ?>
                    <div class="alert alert-error">
                        <span>⚠️</span>
                        <span><?php echo htmlspecialchars($error_message); ?></span>
                    </div>
                <?php endif; ?>

                <?php if ($success_message): ?>
                    <div class="alert alert-success">
                        <span>✅</span>
                        <span><?php echo htmlspecialchars($success_message); ?></span>
                    </div>
                <?php endif; ?>

                <?php if ($searched && count($agreements) > 0): ?>
                    <h2 style="margin-bottom: 20px; color: #333;">Your Latest Agreement</h2>
                    
                    <?php foreach ($agreements as $agreement): ?>
                        <div class="agreement-card">
                            <div class="agreement-details">
                                <div class="detail-item">
                                    <span class="detail-label">Learner Name</span>
                                    <span class="detail-value"><?php echo htmlspecialchars($agreement['learner_name']); ?></span>
                                </div>
                                <div class="detail-item">
                                    <span class="detail-label">Generated Date</span>
                                    <span class="detail-value"><?php echo date('d M Y, H:i', strtotime($agreement['generated_date'])); ?></span>
                                </div>
                                <div class="detail-item">
                                    <span class="detail-label">File Size</span>
                                    <span class="detail-value"><?php echo number_format($agreement['file_size'] / 1024, 2); ?> KB</span>
                                </div>
                                <?php if ($agreement['year'] && $agreement['month']): ?>
                                <div class="detail-item">
                                    <span class="detail-label">Period</span>
                                    <span class="detail-value">
                                        <?php echo date('F Y', mktime(0, 0, 0, $agreement['month'], 1, $agreement['year'])); ?>
                                    </span>
                                </div>
                                <?php endif; ?>
                            </div>

                            <div style="margin-top: 20px; display: flex; gap: 10px; flex-wrap: wrap;">
                                <button type="button" class="btn btn-info" onclick="viewAgreement(<?php echo $agreement['id']; ?>, '<?php echo htmlspecialchars(addslashes($agreement['learner_name'])); ?>')">
                                    👁️ View Agreement
                                </button>
                                <a href="download_agreement_pdf.php?id=<?php echo $agreement['id']; ?>&verify=<?php echo urlencode($id_number); ?>" 
                                   class="btn btn-secondary">
                                    📥 Download PDF
                                </a>
                            </div>
                        </div>
                    <?php endforeach; ?>
                <?php elseif ($searched): ?>
                    <div style="text-align: center; padding: 40px 20px; color: #888;">
                        <div style="font-size: 64px; margin-bottom: 20px; opacity: 0.5;">📭</div>
                        <h3>No Agreements Found</h3>
                        <p>Your agreement may not have been generated yet.</p>
                    </div>
                <?php endif; ?>
            <?php endif; ?>
        </div>
    </div>

    <!-- PDF Viewer Modal -->
    <div class="modal fade" id="pdfViewerModal" tabindex="-1">
        <div class="modal-dialog modal-xl modal-dialog-centered" style="max-width: 95%; height: 90vh;">
            <div class="modal-content" style="height: 100%;">
                <div class="modal-header" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);">
                    <h5 class="modal-title text-white" id="pdfViewerModalLabel">
                        <span>📄</span> <span id="modalLearnerName">Learner Agreement</span>
                    </h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body p-0" style="height: calc(90vh - 120px);">
                    <div id="pdfLoadingSpinner" class="position-absolute top-50 start-50 translate-middle text-center">
                        <div class="spinner-border text-primary" style="width: 3rem; height: 3rem;"></div>
                        <p class="mt-2 text-muted">Loading PDF...</p>
                    </div>
                    <div id="pdfError" class="position-absolute top-50 start-50 translate-middle text-center" style="display: none;">
                        <span style="font-size: 3rem;">⚠️</span>
                        <p class="mt-2 text-danger">Failed to load PDF</p>
                    </div>
                    <iframe id="pdfViewer" class="w-100 h-100 border-0" style="display: none;"></iframe>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
                    <a id="downloadPdfBtn" href="#" class="btn btn-success">📥 Download PDF</a>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        let countdownInterval;
        let storedIdNumber = '';

        // Format ID number input
        document.getElementById('id_number')?.addEventListener('input', function(e) {
            this.value = this.value.replace(/[^0-9]/g, '');
        });

        // Format OTP input
        document.getElementById('otp')?.addEventListener('input', function(e) {
            this.value = this.value.replace(/[^0-9]/g, '');
        });

        // Send OTP
        async function sendOTP(event) {
            event.preventDefault();
            
            const idNumber = document.getElementById('id_number').value;
            const btn = document.getElementById('sendOtpBtn');
            
            if (idNumber.length !== 13) {
                alert('Please enter a valid 13-digit ID Number.');
                return;
            }

            storedIdNumber = idNumber;
            btn.disabled = true;
            btn.textContent = '⏳ Sending...';

            try {
                const response = await fetch('send_agreement_otp.php', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                    body: `id_number=${encodeURIComponent(idNumber)}`
                });

                const data = await response.json();

                if (data.success) {
                    let message = `Code sent to ${data.masked_phone}`;
                    if (data.existing_otp) {
                        message = `OTP already sent to ${data.masked_phone}. Valid for ${data.minutes_left} more minutes.`;
                    }
                    document.getElementById('otpSentMessage').innerHTML = 
                        `<span>✅</span><span>${message}</span>`;
                    document.getElementById('step1').classList.remove('active');
                    document.getElementById('step2').classList.add('active');
                    
                    // Start countdown - use remaining time if existing OTP
                    const countdownSeconds = data.existing_otp ? (data.minutes_left * 60) : 600;
                    startCountdown(countdownSeconds);
                } else {
                    alert(data.message || 'Failed to send OTP. Please try again.');
                    btn.disabled = false;
                    btn.textContent = '📱 Send Verification Code';
                }
            } catch (error) {
                alert('Error: ' + error.message);
                btn.disabled = false;
                btn.textContent = '📱 Send Verification Code';
            }
        }

        // Verify OTP
        async function verifyOTP(event) {
            event.preventDefault();
            
            const otp = document.getElementById('otp').value;
            const btn = document.getElementById('verifyOtpBtn');

            if (otp.length !== 6) {
                alert('Please enter a valid 6-digit code.');
                return;
            }

            btn.disabled = true;
            btn.textContent = '⏳ Verifying...';

            try {
                const response = await fetch('verify_agreement_otp.php', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                    body: `id_number=${encodeURIComponent(storedIdNumber)}&otp=${encodeURIComponent(otp)}`
                });

                const data = await response.json();

                if (data.success) {
                    window.location.reload();
                } else {
                    let message = data.message || 'Invalid OTP. Please try again.';
                    if (data.debug) {
                        message += '\n\nDebug Info: ' + data.debug;
                    }
                    alert(message);
                    btn.disabled = false;
                    btn.textContent = '✅ Verify & Access Agreement';
                }
            } catch (error) {
                alert('Error: ' + error.message);
                btn.disabled = false;
                btn.textContent = '✅ Verify & Access Agreement';
            }
        }

        // Resend OTP
        function resendOTP() {
            clearInterval(countdownInterval);
            document.getElementById('step2').classList.remove('active');
            document.getElementById('step1').classList.add('active');
            document.getElementById('id_number').value = storedIdNumber;
        }

        // Countdown timer
        function startCountdown(seconds) {
            const countdownEl = document.getElementById('countdown');
            let remaining = seconds;

            countdownInterval = setInterval(() => {
                const minutes = Math.floor(remaining / 60);
                const secs = remaining % 60;
                countdownEl.textContent = `Code expires in ${minutes}:${secs.toString().padStart(2, '0')}`;

                if (remaining <= 0) {
                    clearInterval(countdownInterval);
                    countdownEl.innerHTML = '<strong>⚠️ Code expired. Please request a new one.</strong>';
                }
                remaining--;
            }, 1000);
        }

        // View Agreement
        function viewAgreement(agreementId, learnerName) {
            const modal = new bootstrap.Modal(document.getElementById('pdfViewerModal'));
            document.getElementById('modalLearnerName').textContent = 'Agreement - ' + learnerName;
            document.getElementById('downloadPdfBtn').href = 
                `download_agreement_pdf.php?id=${agreementId}&verify=<?php echo urlencode($id_number ?? ''); ?>`;
            
            document.getElementById('pdfLoadingSpinner').style.display = 'block';
            document.getElementById('pdfViewer').style.display = 'none';
            document.getElementById('pdfError').style.display = 'none';
            
            modal.show();
            
            const pdfUrl = `serve_agreement_pdf_simple.php?id=${agreementId}&verify=<?php echo urlencode($id_number ?? ''); ?>`;
            const iframe = document.getElementById('pdfViewer');
            
            iframe.onload = function() {
                document.getElementById('pdfLoadingSpinner').style.display = 'none';
                iframe.style.display = 'block';
            };
            
            iframe.onerror = function() {
                document.getElementById('pdfLoadingSpinner').style.display = 'none';
                document.getElementById('pdfError').style.display = 'block';
            };
            
            iframe.src = pdfUrl;
        }
    </script>
</body>
</html>
