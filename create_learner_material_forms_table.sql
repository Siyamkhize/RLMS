-- Create table for learner material issuance forms
CREATE TABLE IF NOT EXISTS learner_material_forms (
    id INT AUTO_INCREMENT PRIMARY KEY,
    classID VARCHAR(50) NOT NULL,
    learnerID VARCHAR(50) NOT NULL,
    learnerFullName VARCHAR(255) NOT NULL,
    representativeFullName VARCHAR(255) NOT NULL,
    description VARCHAR(255) NOT NULL,
    subDescription VARCHAR(255) DEFAULT NULL,
    quantity INT NOT NULL DEFAULT 1,
    qualificationName VARCHAR(500) DEFAULT NULL,
    learnerSignature VARCHAR(500) DEFAULT NULL,
    representativeSignature VARCHAR(500) DEFAULT NULL,
    dateCreated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    dateUpdated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_classID (classID),
    INDEX idx_learnerID (learnerID),
    INDEX idx_description (description),
    INDEX idx_dateCreated (dateCreated)
);

-- Add some sample data for testing (optional)
-- INSERT INTO learner_material_forms (classID, learnerID, learnerFullName, representativeFullName, description, subDescription, quantity, qualificationName) 
-- VALUES 
-- ('1', '1001', 'John Doe', 'Jane Smith', 'ToolKit', 'ToolKit', 2, 'Sample Qualification'),
-- ('1', '1002', 'Mary Johnson', 'Bob Wilson', 'Learning Material', '13958 - Learner Guide', 1, 'Sample Qualification');