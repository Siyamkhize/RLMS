/**
 * CHUNKED BULK DOWNLOAD - CLIENT-SIDE PROCESSOR
 * Handles large bulk downloads (2000+ learners) without timing out
 * Processes in small chunks with real-time progress updates
 */

class ChunkedBulkDownloader {
    constructor() {
        this.sessionId = null;
        this.totalChunks = 0;
        this.processedChunks = 0;
        this.progressDiv = null;
        this.button = null;
        this.originalButtonText = '';
        this.chunkSize = 10; // Process 10 learners at a time
    }

    /**
     * Start the chunked download process
     */
    async start(learnerIds, startDate, endDate) {
        console.log(`🚀 Starting chunked download for ${learnerIds.length} learners`);
        
        // Show progress UI
        this.showProgressUI();
        
        try {
            // Step 1: Initialize session
            this.updateProgress('Initializing export session...', 0);
            const sessionData = await this.initializeSession(learnerIds, startDate, endDate);
            
            if (!sessionData.success) {
                throw new Error(sessionData.error || 'Failed to initialize session');
            }
            
            this.sessionId = sessionData.session_id;
            this.totalChunks = sessionData.total_chunks;
            
            console.log(`✅ Session initialized: ${this.sessionId}`);
            console.log(`📦 Total chunks: ${this.totalChunks} (${sessionData.chunk_size} learners per chunk)`);
            
            // Step 2: Process chunks sequentially
            for (let i = 0; i < this.totalChunks; i++) {
                const chunkProgress = Math.round(((i + 1) / this.totalChunks) * 100);
                this.updateProgress(
                    `Processing chunk ${i + 1} of ${this.totalChunks}...`,
                    chunkProgress
                );
                
                const chunkResult = await this.processChunk(i);
                
                if (!chunkResult.success) {
                    console.warn(`⚠️ Chunk ${i} had issues:`, chunkResult);
                }
                
                console.log(`✅ Chunk ${i + 1}/${this.totalChunks} completed:`, chunkResult.chunk_results);
            }
            
            // Step 3: Finalize and create ZIP
            this.updateProgress('Creating ZIP file...', 95);
            const finalResult = await this.finalize();
            
            if (!finalResult.success) {
                throw new Error(finalResult.error || 'Failed to create ZIP file');
            }
            
            // Step 4: Download
            this.updateProgress('Download ready!', 100);
            this.downloadZip(finalResult.zip_file);
            
            // Show success message
            setTimeout(() => {
                alert(`✅ Export completed successfully!\n\n` +
                      `Total learners: ${learnerIds.length}\n` +
                      `Processed in ${this.totalChunks} chunks\n\n` +
                      `Downloading ZIP file...`);
                this.cleanup();
            }, 1000);
            
        } catch (error) {
            console.error('❌ Chunked download failed:', error);
            alert(`Export failed: ${error.message}`);
            this.cleanup();
        }
    }

    /**
     * Initialize export session
     */
    async initializeSession(learnerIds, startDate, endDate) {
        const formData = new FormData();
        formData.append('action', 'start');
        formData.append('learner_ids', JSON.stringify(learnerIds));
        formData.append('start_date', startDate);
        formData.append('end_date', endDate);
        formData.append('chunk_size', this.chunkSize);
        
        const response = await fetch('bulk_export_chunked.php', {
            method: 'POST',
            body: formData
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        return await response.json();
    }

    /**
     * Process a single chunk
     */
    async processChunk(chunkIndex) {
        const formData = new FormData();
        formData.append('action', 'process_chunk');
        formData.append('session_id', this.sessionId);
        formData.append('chunk_index', chunkIndex);
        
        const response = await fetch('bulk_export_chunked.php', {
            method: 'POST',
            body: formData
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        return await response.json();
    }

    /**
     * Finalize and create ZIP
     */
    async finalize() {
        const formData = new FormData();
        formData.append('action', 'finalize');
        formData.append('session_id', this.sessionId);
        
        const response = await fetch('bulk_export_chunked.php', {
            method: 'POST',
            body: formData
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const result = await response.json();
        
        // Verify ZIP file was created successfully
        if (result.success && result.zip_file) {
            const checkResponse = await fetch(`check_zip_file.php?file=${encodeURIComponent(result.zip_file)}`);
            const checkData = await checkResponse.json();
            
            console.log('ZIP file verification:', checkData);
            
            if (!checkData.exists) {
                throw new Error('ZIP file was not created successfully');
            }
            
            if (!checkData.valid_zip) {
                throw new Error('ZIP file is corrupted or invalid');
            }
        }
        
        return result;
    }

    /**
     * Download the ZIP file
     */
    downloadZip(zipFileName) {
        // Use dedicated download script to avoid interference
        window.location.href = `download_zip.php?file=${encodeURIComponent(zipFileName)}`;
    }

    /**
     * Show progress UI
     */
    showProgressUI() {
        this.button = document.getElementById('bulkDownloadBtn');
        if (this.button) {
            this.originalButtonText = this.button.textContent;
            this.button.textContent = '⏳ Processing...';
            this.button.disabled = true;
        }
        
        this.progressDiv = document.createElement('div');
        this.progressDiv.id = 'chunkedProgressDiv';
        this.progressDiv.style.cssText = `
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: white;
            padding: 30px;
            border: 2px solid #3b82f6;
            border-radius: 15px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.3);
            z-index: 10000;
            min-width: 400px;
            text-align: center;
        `;
        this.progressDiv.innerHTML = `
            <h2 style="margin: 0 0 20px 0; color: #1e40af;">🔄 Processing Bulk Export</h2>
            <p style="color: #64748b; margin-bottom: 20px;">
                Generating reports with sick notes and manual registers...
            </p>
            <div style="margin: 20px 0;">
                <div style="background: #e5e7eb; border-radius: 10px; overflow: hidden; height: 30px;">
                    <div id="chunkedProgressBar" style="
                        background: linear-gradient(90deg, #3b82f6, #2563eb);
                        height: 100%;
                        width: 0%;
                        transition: width 0.3s ease;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        color: white;
                        font-weight: bold;
                        font-size: 14px;
                    "></div>
                </div>
            </div>
            <p id="chunkedProgressText" style="color: #475569; font-size: 14px; margin: 10px 0;">
                Initializing...
            </p>
            <small style="color: #94a3b8;">
                📄 This may take a few minutes for large exports
            </small>
        `;
        document.body.appendChild(this.progressDiv);
    }

    /**
     * Update progress display
     */
    updateProgress(message, percent) {
        const progressText = document.getElementById('chunkedProgressText');
        const progressBar = document.getElementById('chunkedProgressBar');
        
        if (progressText) {
            progressText.textContent = message;
        }
        
        if (progressBar) {
            progressBar.style.width = percent + '%';
            progressBar.textContent = percent + '%';
        }
    }

    /**
     * Cleanup UI
     */
    cleanup() {
        if (this.progressDiv && this.progressDiv.parentNode) {
            this.progressDiv.parentNode.removeChild(this.progressDiv);
        }
        
        if (this.button) {
            this.button.textContent = this.originalButtonText;
            this.button.disabled = false;
        }
    }
}

/**
 * Main function to start bulk download with chunked processing
 */
async function startChunkedBulkDownload() {
    // Check if any learners are displayed
    const learnerRows = document.querySelectorAll('.learner-row');
    if (learnerRows.length === 0) {
        alert('No learners found. Please run a search first to display learners.');
        return;
    }

    // Extract learner IDs from the table
    const learnerIds = [];
    learnerRows.forEach(row => {
        const viewReportLink = row.querySelector('a[href*="indivisual.php"]');
        if (viewReportLink) {
            const href = viewReportLink.getAttribute('href');
            const learnerIdMatch = href.match(/LearnerID=(\d+)/);
            if (learnerIdMatch) {
                learnerIds.push(parseInt(learnerIdMatch[1]));
            }
        }
    });

    if (learnerIds.length === 0) {
        alert('No valid learner IDs found in the current results.');
        return;
    }

    // Confirm for large batches
    if (learnerIds.length > 100) {
        const confirmed = confirm(
            `You are about to export ${learnerIds.length} learner reports.\n\n` +
            `This will include:\n` +
            `• Individual attendance reports (PDF)\n` +
            `• Sick notes (where available)\n` +
            `• Manual attendance registers (where available)\n\n` +
            `This may take several minutes. Continue?`
        );
        
        if (!confirmed) {
            return;
        }
    }

    // Get date range
    const urlParams = new URLSearchParams(window.location.search);
    const startDateInput = document.getElementById('start_date');
    const endDateInput = document.getElementById('end_date');
    
    let startDate, endDate;
    
    if (startDateInput && startDateInput.value) {
        startDate = startDateInput.value;
    } else if (urlParams.get('start_date')) {
        startDate = urlParams.get('start_date');
    } else {
        const now = new Date();
        startDate = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0];
    }
    
    if (endDateInput && endDateInput.value) {
        endDate = endDateInput.value;
    } else if (urlParams.get('end_date')) {
        endDate = urlParams.get('end_date');
    } else {
        const now = new Date();
        endDate = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().split('T')[0];
    }

    console.log(`📦 Starting chunked export for ${learnerIds.length} learners`);
    console.log(`📅 Date range: ${startDate} to ${endDate}`);

    // Start chunked download
    const downloader = new ChunkedBulkDownloader();
    await downloader.start(learnerIds, startDate, endDate);
}

// Make function globally available
window.startChunkedBulkDownload = startChunkedBulkDownload;
