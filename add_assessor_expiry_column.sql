-- Add assessorExpiryDate column to facilitator table
-- Run this on your server database to add the new column

ALTER TABLE facilitator ADD COLUMN assessorExpiryDate VARCHAR(10) DEFAULT NULL;

-- Optional: Add a comment to document the column
ALTER TABLE facilitator MODIFY COLUMN assessorExpiryDate VARCHAR(10) DEFAULT NULL COMMENT 'Assessor certificate expiry date in DD/MM/YYYY format';

-- Verify the column was added
DESCRIBE facilitator;