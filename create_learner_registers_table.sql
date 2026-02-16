-- Create learner_registers table for finance role
 

-- Add finance role to users table if not exists
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'learner';

-- Sample finance user (update with actual credentials)
-- INSERT INTO users (email, password, role, name, surname) 
-- VALUES ('finance@example.com', MD5('password123'), 'finance', 'Finance', 'User');
