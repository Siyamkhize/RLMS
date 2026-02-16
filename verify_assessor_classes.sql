-- verify_assessor_classes.sql
-- SQL queries to verify assessor/facilitator class associations

-- 1. Check all facilitators and their roles
SELECT 
    facilitator_id,
    firstName,
    lastName,
    role,
    classID,
    email
FROM facilitator
WHERE role IN ('Assessor', 'assessor', 'ASSESSOR')
ORDER BY facilitator_id
LIMIT 20;

-- 2. Check classes linked to facilitators
SELECT 
    f.facilitator_id,
    f.firstName,
    f.lastName,
    f.role,
    f.classID,
    c.className,
    c.siteID,
    s.siteName,
    s.project_id
FROM facilitator f
LEFT JOIN class c ON f.classID = c.classID
LEFT JOIN sites s ON c.siteID = s.siteID
WHERE f.role IN ('Assessor', 'assessor', 'ASSESSOR')
ORDER BY f.facilitator_id
LIMIT 20;

-- 3. Count learners per class for assessors
SELECT 
    f.facilitator_id,
    f.firstName,
    f.lastName,
    c.classID,
    c.className,
    COUNT(DISTINCT ld.LearnerID) as numberOfLearners
FROM facilitator f
INNER JOIN class c ON f.classID = c.classID
LEFT JOIN learnerdetails ld ON c.classID = ld.classID
WHERE f.role IN ('Assessor', 'assessor', 'ASSESSOR')
GROUP BY f.facilitator_id, f.firstName, f.lastName, c.classID, c.className
ORDER BY f.facilitator_id;

-- 4. Check for facilitators without classes
SELECT 
    facilitator_id,
    firstName,
    lastName,
    role,
    classID
FROM facilitator
WHERE role IN ('Assessor', 'assessor', 'ASSESSOR')
AND (classID IS NULL OR classID = '' OR classID = '0')
LIMIT 20;

-- 5. Check for classes without facilitators
SELECT 
    c.classID,
    c.className,
    c.siteID,
    s.siteName,
    COUNT(DISTINCT ld.LearnerID) as numberOfLearners
FROM class c
LEFT JOIN sites s ON c.siteID = s.siteID
LEFT JOIN learnerdetails ld ON c.classID = ld.classID
WHERE c.classID NOT IN (SELECT DISTINCT classID FROM facilitator WHERE classID IS NOT NULL)
GROUP BY c.classID, c.className, c.siteID, s.siteName
LIMIT 20;

-- 6. Test query for a specific facilitator_id (replace '1' with actual ID)
SELECT DISTINCT
    c.classID,
    c.className,
    c.siteID,
    s.siteName,
    s.project_id,
    p.Project_name,
    COUNT(DISTINCT ld.LearnerID) as numberOfLearners
FROM facilitator f
INNER JOIN class c ON f.classID = c.classID
INNER JOIN sites s ON c.siteID = s.siteID
LEFT JOIN project p ON s.project_id = p.project_id
LEFT JOIN learnerdetails ld ON c.classID = ld.classID
WHERE f.facilitator_id = '1'  -- CHANGE THIS TO TEST SPECIFIC FACILITATOR
GROUP BY c.classID, c.className, c.siteID, s.siteName, s.project_id, p.Project_name
ORDER BY c.className;

-- 7. Check table structures
DESCRIBE facilitator;
DESCRIBE class;
DESCRIBE sites;
DESCRIBE project;
DESCRIBE learnerdetails;

-- 8. Sample data from each table
SELECT * FROM facilitator LIMIT 5;
SELECT * FROM class LIMIT 5;
SELECT * FROM sites LIMIT 5;
SELECT * FROM project LIMIT 5;
SELECT * FROM learnerdetails LIMIT 5;
