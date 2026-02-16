<?php
ob_start();
include('sdp_header.php');

// Ensure session is active and SDP credentials are valid
if (!isset($_SESSION['sdp_name']) || !isset($_SESSION['sdp_id'])) {
    error_log("Session check failed: sdp_name or sdp_id not set");
    echo "<script>alert('Invalid SDP credentials. Please log in again.'); window.location.href='index.php';</script>";
    exit;
}

$sdp_name = $_SESSION['sdp_name'];
$sdp_id = $_SESSION['sdp_id'];

// Get learners with POE documents
$learnersSql = "SELECT DISTINCT learner_id, learner_name, class_id, site_name,
                COUNT(*) as document_count,
                MAX(upload_date) as last_upload
                FROM poe_documents 
                WHERE status = 'active' 
                GROUP BY learner_id, learner_name, class_id, site_name
                ORDER BY learner_name ASC";
$learnersResult = $conn->query($learnersSql);
$learners = $learnersResult ? $learnersResult->fetch_all(MYSQLI_ASSOC) : [];

// Get total statistics
$statsSql = "SELECT 
             COUNT(DISTINCT learner_id) as total_learners,
             COUNT(*) as total_documents,
             SUM(file_size) as total_size
             FROM poe_documents 
             WHERE status = 'active'";
$statsResult = $conn->query($statsSql);
$stats = $statsResult ? $statsResult->fetch_assoc() : ['total_learners' => 0, 'total_documents' => 0, 'total_size' => 0];
?>

<style>
.merge-container {
    background: linear-gradient(135deg, #f8fafc 0%, #e3e9f7 100%);
    min-height: 100vh;
    padding: 2rem 0;
}

.stats-card {
    background: linear-gradient(135deg, #2563eb 0%, #60a5fa 100%);
    color: white;
    border-radius: 16px;
    padding: 1.5rem;
    margin-bottom: 2rem;
    box-shadow: 0 4px 20px rgba(37,99,235,0.15);
}

.stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
    margin-top: 1rem;
}

.stat-item {
    text-align: center;
    padding: 1rem;
    background: rgba(255,255,255,0.1);
    border-radius: 12px;
}

.stat-number {
    font-size: 2rem;
    font-weight: bold;
    display: block;
}

.stat-label {
    font-size: 0.9rem;
    opacity: 0.9;
}

.learner-card {
    background: white;
    border-radius: 12px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.08);
    margin-bottom: 1rem;
    padding: 1.5rem;
    border-left: 4px solid #2563eb;
    transition: transform 0.2s, box-shadow 0.2s;
}

.learner-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 20px rgba(0,0,0,0.12);
}

.learner-info {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
}

.learner-details h6 {
    margin: 0;
    color: #374151;
    font-weight: 600;
}

.learner-meta {
    color: #6b7280;
    font-size: 0.9rem;
    margin-top: 0.5rem;
}

.action-buttons {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
}

.btn-merge {
    background: linear-gradient(135deg, #059669 0%, #10b981 100%);
    border: none;
    border-radius: 8px;
    padding: 0.5rem 1rem;
    color: white;
    font-weight: 500;
    text-decoration: none;
    font-size: 0.9rem;
    cursor: pointer;
}

.btn-merge:hover {
    color: white;
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(5,150,105,0.3);
}

.btn-merge-all {
    background: linear-gradient(135deg, #dc2626 0%, #ef4444 100%);
    border: none;
    border-radius: 12px;
    padding: 0.75rem 2rem;
    color: white;
    font-weight: 600;
    font-size: 1rem;
    cursor: pointer;
    margin-bottom: 2rem;
}

.btn-merge-all:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 20px rgba(220,38,38,0.3);
}

.loading {
    display: none;
    text-align: center;
    padding: 2rem;
}

.spinner {
    border: 4px solid #f3f4f6;
    border-top: 4px solid #2563eb;
    border-radius: 50%;
    width: 40px;
    height: 40px;
    animation: spin 1s linear infinite;
    margin: 0 auto 1rem;
}

@keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}

@media (max-width: 768px) {
    .learner-info {
        flex-direction: column;
        align-items: flex-start;
    }
    
    .action-buttons {
        width: 100%;
        justify-content: flex-start;
    }
}
</style>

<div class="merge-container">
    <div class="container">
        <div class="row">
            <div class="col-12">
                <h2 class="mb-4">POE Document Merge Manager</h2>
                
                <!-- Statistics Card -->
                <div class="stats-card">
                    <h4 class="mb-0">POE Documents Overview</h4>
                    <div class="stats-grid">
                        <div class="stat-item">
                            <span class="stat-number"><?php echo number_format($stats['total_learners']); ?></span>
                            <span class="stat-label">Learners with POE</span>
                        </div>
                        <div class="stat-item">
                            <span class="stat-number"><?php echo number_format($stats['total_documents']); ?></span>
                            <span class="stat-label">Total Documents</span>
                        </div>
                        <div class="stat-item">
                            <span class="stat-number"><?php echo formatBytes($stats['total_size']); ?></span>
                            <span class="stat-label">Total Size</span>
                        </div>
                    </div>
                </div>
                
                <!-- Options Explanation -->
                <div class="alert alert-info" style="background: linear-gradient(135deg, #e0f2fe 0%, #b3e5fc 100%); border: 1px solid #81d4fa; border-radius: 12px; padding: 1rem; margin-bottom: 1rem;">
                    <h5 style="color: #0277bd; margin-bottom: 0.5rem;"><i class="mdi mdi-information me-2"></i>Document Merge Options</h5>
                    <div style="color: #01579b; font-size: 0.9rem;">
                        <p style="margin-bottom: 0.5rem;"><strong>Merge PDF Pages:</strong> Attempts to combine the actual PDF content into a single file. Due to server limitations (no system PDF tools), this may show only one document or have formatting issues.</p>
                        <p style="margin-bottom: 0.5rem;"><strong>Portfolio PDF:</strong> Creates a comprehensive document with cover page, table of contents, and detailed information about each POE document. Perfect for reviews and assessments.</p>
                        <p style="margin: 0;"><strong>ZIP Archive:</strong> Downloads all original PDF files in a single ZIP archive. <strong>Recommended when you need all actual documents.</strong></p>
                    </div>
                </div>
                
                <!-- Database Health Check -->
                <div class="alert alert-info" style="background: linear-gradient(135deg, #e0f2fe 0%, #b3e5fc 100%); border: 1px solid #81d4fa; border-radius: 12px; padding: 1rem; margin-bottom: 1rem;">
                    <h6 style="color: #0277bd; margin-bottom: 0.5rem;"><i class="mdi mdi-database-check me-2"></i>Database Health Status</h6>
                    <div style="color: #01579b; font-size: 0.9rem;">
                        <p style="margin-bottom: 0.5rem;">System automatically monitors for data corruption issues.</p>
                        <div style="display: flex; gap: 10px; flex-wrap: wrap;">
                            <a href="test_corruption_fix.php" style="background: #2563eb; color: white; padding: 6px 12px; text-decoration: none; border-radius: 6px; font-size: 0.8rem;">🔍 Check Health</a>
                            <a href="quick_corruption_fix.php" style="background: #dc2626; color: white; padding: 6px 12px; text-decoration: none; border-radius: 6px; font-size: 0.8rem;">🔧 Fix Issues</a>
                            <a href="view_corruption_backup.php" style="background: #7c3aed; color: white; padding: 6px 12px; text-decoration: none; border-radius: 6px; font-size: 0.8rem;">📋 View Backups</a>
                        </div>
                    </div>
                </div>

                <!-- Technical Limitation Notice -->
                <div class="alert alert-warning" style="background: linear-gradient(135deg, #fff8e1 0%, #ffecb3 100%); border: 1px solid #ffb74d; border-radius: 12px; padding: 1rem; margin-bottom: 2rem;">
                    <h6 style="color: #e65100; margin-bottom: 0.5rem;"><i class="mdi mdi-alert me-2"></i>Technical Limitation</h6>
                    <div style="color: #bf360c; font-size: 0.85rem;">
                        <p style="margin: 0;">True PDF page merging requires specialized tools (pdftk, qpdf) or libraries (FPDI) that are not available on this server. The "Merge PDF Pages" option attempts basic concatenation but may not work perfectly. For reliable access to all documents, use the <strong>ZIP Archive</strong> option.</p>
                    </div>
                </div>
                
                <!-- Merge All Button -->
                <?php if (!empty($learners)): ?>
                <button onclick="mergeAllDocuments()" class="btn-merge-all">
                    <i class="mdi mdi-merge me-2"></i>Merge All Learners' Documents
                </button>
                <?php endif; ?>
                
                <!-- Loading Indicator -->
                <div id="loadingIndicator" class="loading">
                    <div class="spinner"></div>
                    <p>Merging documents, please wait...</p>
                </div>
                
                <!-- Learners List -->
                <?php if (empty($learners)): ?>
                    <div class="learner-card text-center">
                        <i class="mdi mdi-file-document-outline" style="font-size: 4rem; color: #9ca3af; margin-bottom: 1rem;"></i>
                        <h5 class="text-muted">No POE documents found</h5>
                        <p class="text-muted">POE documents will appear here once uploaded.</p>
                    </div>
                <?php else: ?>
                    <?php foreach ($learners as $learner): ?>
                        <div class="learner-card">
                            <div class="learner-info">
                                <div class="learner-details">
                                    <h6><?php echo htmlspecialchars($learner['learner_name']); ?></h6>
                                    <div class="learner-meta">
                                        ID: <?php echo htmlspecialchars($learner['learner_id']); ?> | 
                                        Class: <?php echo htmlspecialchars($learner['class_id'] ?: 'N/A'); ?> | 
                                        Site: <?php echo htmlspecialchars($learner['site_name'] ?: 'N/A'); ?>
                                        <br>
                                        Documents: <?php echo $learner['document_count']; ?> | 
                                        Last Upload: <?php echo date('M d, Y', strtotime($learner['last_upload'])); ?>
                                    </div>
                                </div>
                                <div class="action-buttons">
                                    <button onclick="mergeLearnerDocuments('<?php echo htmlspecialchars($learner['learner_id']); ?>', 'actual')" 
                                            class="btn-merge">
                                        <i class="mdi mdi-merge me-1"></i>Merge PDF Pages
                                    </button>
                                    <button onclick="mergeLearnerDocuments('<?php echo htmlspecialchars($learner['learner_id']); ?>', 'portfolio')" 
                                            class="btn btn-sm" style="background: linear-gradient(135deg, #059669 0%, #10b981 100%); color: white; border: none; border-radius: 8px; padding: 0.5rem 1rem;">
                                        <i class="mdi mdi-file-document me-1"></i>Portfolio PDF
                                    </button>
                                    <button onclick="mergeLearnerDocuments('<?php echo htmlspecialchars($learner['learner_id']); ?>', 'zip')" 
                                            class="btn btn-sm" style="background: linear-gradient(135deg, #7c3aed 0%, #a855f7 100%); color: white; border: none; border-radius: 8px; padding: 0.5rem 1rem;">
                                        <i class="mdi mdi-zip-box me-1"></i>ZIP Archive
                                    </button>
                                    <a href="view_learner_poe.php?learner_id=<?php echo urlencode($learner['learner_id']); ?>" 
                                       class="btn btn-sm btn-outline-primary" style="border-radius: 8px;">
                                        <i class="mdi mdi-eye me-1"></i>View Files
                                    </a>
                                    <a href="debug_merge_final.php?learner_id=<?php echo urlencode($learner['learner_id']); ?>" 
                                       class="btn btn-sm btn-outline-info" style="border-radius: 8px;" target="_blank">
                                        <i class="mdi mdi-bug me-1"></i>Debug
                                    </a>
                                </div>
                            </div>
                        </div>
                    <?php endforeach; ?>
                <?php endif; ?>
            </div>
        </div>
    </div>
</div>

<script>
function mergeLearnerDocuments(learnerId, method = 'actual') {
    showLoading(true);
    
    // Determine which script to use
    let scriptUrl = 'merge_poe_working.php';
    if (method === 'actual') {
        scriptUrl = 'merge_poe_direct.php'; // Use direct PDF merger
    }
    
    // Create a form and submit it to trigger download
    const form = document.createElement('form');
    form.method = 'GET';
    form.action = scriptUrl;
    form.target = '_blank';
    
    const learnerInput = document.createElement('input');
    learnerInput.type = 'hidden';
    learnerInput.name = 'learner_id';
    learnerInput.value = learnerId;
    
    const actionInput = document.createElement('input');
    actionInput.type = 'hidden';
    actionInput.name = 'action';
    actionInput.value = 'merge_single';
    
    if (method !== 'actual') {
        const methodInput = document.createElement('input');
        methodInput.type = 'hidden';
        methodInput.name = 'method';
        methodInput.value = method;
        form.appendChild(methodInput);
    }
    
    form.appendChild(learnerInput);
    form.appendChild(actionInput);
    document.body.appendChild(form);
    form.submit();
    document.body.removeChild(form);
    
    // Hide loading after a delay
    setTimeout(() => {
        showLoading(false);
    }, 5000);
}

function mergeAllDocuments() {
    if (!confirm('This will merge documents for all learners. This may take a while. Continue?')) {
        return;
    }
    
    showLoading(true);
    
    // Create a form and submit it to trigger download
    const form = document.createElement('form');
    form.method = 'GET';
    form.action = 'merge_poe_system_tools.php';
    form.target = '_blank';
    
    const actionInput = document.createElement('input');
    actionInput.type = 'hidden';
    actionInput.name = 'action';
    actionInput.value = 'merge_all';
    
    form.appendChild(actionInput);
    document.body.appendChild(form);
    form.submit();
    document.body.removeChild(form);
    
    // Hide loading after a delay
    setTimeout(() => {
        showLoading(false);
    }, 10000);
}

function showLoading(show) {
    const loadingIndicator = document.getElementById('loadingIndicator');
    loadingIndicator.style.display = show ? 'block' : 'none';
}
</script>

<?php
function formatBytes($size, $precision = 2) {
    $units = array('B', 'KB', 'MB', 'GB', 'TB');
    
    for ($i = 0; $size > 1024 && $i < count($units) - 1; $i++) {
        $size /= 1024;
    }
    
    return round($size, $precision) . ' ' . $units[$i];
}
?>

<?php include('sdp_footer.php'); ?>
<?php ob_end_flush(); ?>