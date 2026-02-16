-- Create indexes for optimized search performance
-- These indexes will dramatically improve search speed

-- Index for classID (most common filter)
CREATE INDEX IF NOT EXISTS idx_learnerdetails_classid ON learnerdetails(classID);

-- Index for ID Number searches
CREATE INDEX IF NOT EXISTS idx_learnerdetails_idnumber ON learnerdetails(IDNumber);

-- Index for name searches
CREATE INDEX IF NOT EXISTS idx_learnerdetails_name ON learnerdetails(Name);
CREATE INDEX IF NOT EXISTS idx_learnerdetails_surname ON learnerdetails(Surname);

-- Composite index for classID + Name (common combination)
CREATE INDEX IF NOT EXISTS idx_learnerdetails_class_name ON learnerdetails(classID, Name, Surname);

-- Composite index for classID + IDNumber (common combination)
CREATE INDEX IF NOT EXISTS idx_learnerdetails_class_id ON learnerdetails(classID, IDNumber);

-- Index for phone number searches
CREATE INDEX IF NOT EXISTS idx_learnerdetails_phone ON learnerdetails(PhoneNumber);

-- Index for synced status (for sync operations)
CREATE INDEX IF NOT EXISTS idx_learnerdetails_synced ON learnerdetails(synced);

-- Full-text index for comprehensive text search (if MySQL version supports it)
-- ALTER TABLE learnerdetails ADD FULLTEXT(Name, Surname, IDNumber, PhoneNumber);

-- Show index creation results
SHOW INDEX FROM learnerdetails WHERE Key_name LIKE 'idx_%';