-- Check if both unit standards exist for a learner
-- Replace 17391 with your actual learner_id

SELECT 
    learner_id,
    unit_standard_id,
    marks,
    moderator_status,
    moderator_comment,
    assessor_comment,
    assessment_date
FROM logbook_marks 
WHERE learner_id = '17391' 
  AND unit_standard_id IN ('13958', '14555')
ORDER BY unit_standard_id ASC;

-- This should return 2 rows if both unit standards have marks
-- If you only see 1 row, then only one unit standard has been marked
