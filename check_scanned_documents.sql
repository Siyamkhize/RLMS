-- Check if scanned documents table exists and has data

-- 1. Check if table exists
SHOW TABLES LIKE 'pothole_checklist_scanned_documents';

-- 2. Check table structure
DESCRIBE pothole_checklist_scanned_documents;

-- 3. Count total records
SELECT COUNT(*) as total_scanned_documents 
FROM pothole_checklist_scanned_documents;

-- 4. List all scanned documents
SELECT 
    id,
    learner_id,
    assessor_id,
    document_path,
    assessment_date,
    created_at
FROM pothole_checklist_scanned_documents
ORDER BY created_at DESC
LIMIT 10;

-- 5. Check for specific learner (learner 70)
SELECT * 
FROM pothole_checklist_scanned_documents 
WHERE learner_id = '70';

-- 6. Check for the document you mentioned
SELECT * 
FROM pothole_checklist_scanned_documents 
WHERE document_path LIKE '%pothole_checklist_1231_1762330576.pdf%';

-- 7. List all learners with scanned documents
SELECT 
    learner_id,
    COUNT(*) as document_count,
    MAX(created_at) as latest_upload
FROM pothole_checklist_scanned_documents
GROUP BY learner_id
ORDER BY latest_upload DESC;
