-- Insert database record for the scanned document that exists on server
-- File: /public_html/tesing.mtltechnical.co.za/uploads/pothole_checklists/pothole_checklist_70_1762423169.pdf

INSERT INTO pothole_checklist_scanned_documents 
(learner_id, assessor_id, document_path, assessment_date, created_at)
VALUES 
('70', '6', '../uploads/pothole_checklists/pothole_checklist_70_1762423169.pdf', CURDATE(), NOW());

-- Verify the record was created
SELECT * FROM pothole_checklist_scanned_documents WHERE learner_id = '70';

-- Expected result:
-- | id | learner_id | assessor_id | document_path                                                  | assessment_date | created_at          |
-- |----|------------|-------------|----------------------------------------------------------------|-----------------|---------------------|
-- | 1  | 70         | 6           | ../uploads/pothole_checklists/pothole_checklist_70_1762423169.pdf | 2025-11-06      | 2025-11-06 15:30:00 |
