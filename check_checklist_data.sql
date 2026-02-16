-- Quick SQL script to check if pothole checklist data exists
-- Run this to verify you have data in the database

-- Check scanned documents
SELECT 
    'SCANNED DOCUMENTS' as table_name,
    COUNT(*) as total_count,
    COUNT(DISTINCT learner_id) as unique_learners,
    MAX(uploaded_at) as latest_upload
FROM pothole_checklist_scanned_documents;

-- List recent scanned documents
SELECT 
    id,
    learner_id,
    learner_name,
    assessor_id,
    document_path,
    assessment_date,
    uploaded_at
FROM pothole_checklist_scanned_documents
ORDER BY uploaded_at DESC
LIMIT 5;

-- Check system-generated checklists
SELECT 
    'SYSTEM CHECKLISTS' as table_name,
    COUNT(*) as total_count,
    COUNT(DISTINCT learner_id) as unique_learners,
    MAX(assessment_date) as latest_assessment
FROM pothole_checklists;

-- List recent system checklists with item counts
SELECT 
    pc.id,
    pc.learner_id,
    pc.learner_name,
    pc.assessor_id,
    pc.assessment_date,
    COUNT(pci.id) as item_count,
    pc.created_at
FROM pothole_checklists pc
LEFT JOIN pothole_checklist_items pci ON pc.id = pci.checklist_id
GROUP BY pc.id
ORDER BY pc.created_at DESC
LIMIT 5;

-- Check for specific learner (replace 'YOUR_LEARNER_ID' with actual ID)
-- Uncomment and modify the line below:
-- SELECT * FROM pothole_checklist_scanned_documents WHERE learner_id = 'YOUR_LEARNER_ID';
-- SELECT * FROM pothole_checklists WHERE learner_id = 'YOUR_LEARNER_ID';
