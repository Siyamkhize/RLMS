-- Create material forms table for logistics and facilitator material distribution forms

-- Add logistics users to existing account_user table
-- First ensure the role column exists (if not already present)
ALTER TABLE account_user ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'Account';

-- Insert logistics users into account_user table
INSERT IGNORE INTO account_user (account_name, username, email, password, role, sdp_id) VALUES 
('Logistics Manager', 'logistics', 'logistics@example.com', MD5('logistics123'), 'logistics', 1),
('Logistics Officer', 'logistics_officer', 'logistics.officer@example.com', MD5('logistics123'), 'logistics', 1),
('Material Coordinator', 'material_coord', 'material.coord@example.com', MD5('logistics123'), 'logistics', 1);

-- Ensure sites table exists with required columns for logistics
CREATE TABLE IF NOT EXISTS sites (
    siteID INT AUTO_INCREMENT PRIMARY KEY,
    siteName VARCHAR(255) NOT NULL,
    beneficiaries INT DEFAULT 0,
    Project_pathway VARCHAR(255) DEFAULT NULL,
    Category VARCHAR(255) DEFAULT NULL,
    province VARCHAR(255) DEFAULT NULL,
    sdp_id INT DEFAULT NULL,
    latitude DECIMAL(10, 8) DEFAULT NULL,
    longitude DECIMAL(11, 8) DEFAULT NULL,
    address TEXT DEFAULT NULL,
    contact_person VARCHAR(255) DEFAULT NULL,
    contact_phone VARCHAR(50) DEFAULT NULL,
    contact_email VARCHAR(255) DEFAULT NULL,
    status ENUM('Active', 'Inactive', 'Suspended') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_site_name (siteName),
    INDEX idx_province (province),
    INDEX idx_sdp (sdp_id),
    INDEX idx_status (status),
    INDEX idx_coordinates (latitude, longitude)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Ensure class table exists with required columns for logistics
CREATE TABLE IF NOT EXISTS class (
    classID INT AUTO_INCREMENT PRIMARY KEY,
    className VARCHAR(255) NOT NULL,
    siteID INT NOT NULL,
    facilitator_id INT DEFAULT NULL,
    startDate DATE DEFAULT NULL,
    endDate DATE DEFAULT NULL,
    status ENUM('Active', 'Completed', 'Suspended', 'Cancelled') DEFAULT 'Active',
    max_learners INT DEFAULT 30,
    current_learners INT DEFAULT 0,
    qualification_id INT DEFAULT NULL,
    description TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (siteID) REFERENCES sites(siteID) ON DELETE CASCADE,
    INDEX idx_class_name (className),
    INDEX idx_site (siteID),
    INDEX idx_facilitator (facilitator_id),
    INDEX idx_status (status),
    INDEX idx_dates (startDate, endDate)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Ensure facilitator table exists for class assignments
CREATE TABLE IF NOT EXISTS facilitator (
    facilitator_id INT AUTO_INCREMENT PRIMARY KEY,
    firstName VARCHAR(255) NOT NULL,
    lastName VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE DEFAULT NULL,
    phone VARCHAR(50) DEFAULT NULL,
    id_number VARCHAR(50) UNIQUE DEFAULT NULL,
    qualification VARCHAR(255) DEFAULT NULL,
    status ENUM('Active', 'Inactive', 'Suspended') DEFAULT 'Active',
    hire_date DATE DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_name (firstName, lastName),
    INDEX idx_email (email),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Material forms table for logistics and facilitator material distribution forms
CREATE TABLE IF NOT EXISTS material_forms (
    id INT AUTO_INCREMENT PRIMARY KEY,
    form_number VARCHAR(50) UNIQUE NOT NULL,
    classID INT DEFAULT NULL,
    siteID INT DEFAULT NULL,
    facilitator_full_name VARCHAR(255) DEFAULT NULL,
    facilitator_id_number VARCHAR(50) DEFAULT NULL,
    representative_full_name VARCHAR(255) DEFAULT NULL,
    representative_id_number VARCHAR(50) DEFAULT NULL,
    qualification_name VARCHAR(255) DEFAULT NULL,
    facilitator_signature TEXT NOT NULL,
    representative_signature TEXT NOT NULL,
    material_type VARCHAR(100) DEFAULT NULL,
    description TEXT DEFAULT NULL,
    sub_description TEXT DEFAULT NULL,
    quantity INT DEFAULT NULL,
    unit_of_measure VARCHAR(50) DEFAULT 'pieces',
    issue_date DATE NOT NULL,
    expected_return_date DATE DEFAULT NULL,
    purpose TEXT DEFAULT NULL,
    condition_issued ENUM('New', 'Good', 'Fair', 'Poor') DEFAULT 'Good',
    status ENUM('Issued', 'Returned', 'Overdue', 'Lost', 'Damaged') DEFAULT 'Issued',
    is_synced TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (classID) REFERENCES class(classID) ON DELETE SET NULL,
    FOREIGN KEY (siteID) REFERENCES sites(siteID) ON DELETE SET NULL,
    INDEX idx_form_number (form_number),
    INDEX idx_class (classID),
    INDEX idx_site (siteID),
    INDEX idx_facilitator (facilitator_full_name),
    INDEX idx_material_type (material_type),
    INDEX idx_issue_date (issue_date),
    INDEX idx_status (status),
    INDEX idx_sync_status (is_synced),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Material receipt forms table for tracking returns and receipts
CREATE TABLE IF NOT EXISTS material_receipt_form (
    receipt_id INT AUTO_INCREMENT PRIMARY KEY,
    receipt_number VARCHAR(50) UNIQUE NOT NULL,
    material_form_id INT NOT NULL,
    form_number VARCHAR(50) NOT NULL,
    classID INT DEFAULT NULL,
    siteID INT DEFAULT NULL,
    facilitator_full_name VARCHAR(255) DEFAULT NULL,
    facilitator_id_number VARCHAR(50) DEFAULT NULL,
    representative_full_name VARCHAR(255) DEFAULT NULL,
    representative_id_number VARCHAR(50) DEFAULT NULL,
    material_type VARCHAR(100) DEFAULT NULL,
    description TEXT DEFAULT NULL,
    quantity_returned INT DEFAULT NULL,
    quantity_damaged INT DEFAULT 0,
    quantity_lost INT DEFAULT 0,
    unit_of_measure VARCHAR(50) DEFAULT 'pieces',
    return_date DATE NOT NULL,
    condition_returned ENUM('New', 'Good', 'Fair', 'Poor', 'Damaged', 'Lost') DEFAULT 'Good',
    facilitator_signature TEXT NOT NULL,
    representative_signature TEXT NOT NULL,
    receiver_name VARCHAR(255) DEFAULT NULL,
    receiver_signature TEXT DEFAULT NULL,
    notes TEXT DEFAULT NULL,
    damage_report TEXT DEFAULT NULL,
    replacement_required TINYINT(1) DEFAULT 0,
    replacement_cost DECIMAL(10,2) DEFAULT 0.00,
    status ENUM('Received', 'Processed', 'Pending_Replacement', 'Completed') DEFAULT 'Received',
    is_synced TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (material_form_id) REFERENCES material_forms(id) ON DELETE CASCADE,
    FOREIGN KEY (classID) REFERENCES class(classID) ON DELETE SET NULL,
    FOREIGN KEY (siteID) REFERENCES sites(siteID) ON DELETE SET NULL,
    INDEX idx_receipt_number (receipt_number),
    INDEX idx_material_form (material_form_id),
    INDEX idx_form_number (form_number),
    INDEX idx_class (classID),
    INDEX idx_site (siteID),
    INDEX idx_return_date (return_date),
    INDEX idx_status (status),
    INDEX idx_sync_status (is_synced)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Material tracking summary table for dashboard and reporting
CREATE TABLE IF NOT EXISTS material_tracking_summary (
    tracking_id INT AUTO_INCREMENT PRIMARY KEY,
    material_type VARCHAR(100) NOT NULL,
    classID INT DEFAULT NULL,
    siteID INT DEFAULT NULL,
    site_name VARCHAR(255) DEFAULT NULL,
    class_name VARCHAR(255) DEFAULT NULL,
    total_issued INT DEFAULT 0,
    total_returned INT DEFAULT 0,
    total_damaged INT DEFAULT 0,
    total_lost INT DEFAULT 0,
    total_outstanding INT DEFAULT 0,
    total_overdue INT DEFAULT 0,
    last_issue_date DATE DEFAULT NULL,
    last_return_date DATE DEFAULT NULL,
    total_forms_issued INT DEFAULT 0,
    total_forms_returned INT DEFAULT 0,
    estimated_value DECIMAL(12,2) DEFAULT 0.00,
    replacement_cost DECIMAL(12,2) DEFAULT 0.00,
    status ENUM('Active', 'Completed', 'Alert') DEFAULT 'Active',
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (classID) REFERENCES class(classID) ON DELETE SET NULL,
    FOREIGN KEY (siteID) REFERENCES sites(siteID) ON DELETE SET NULL,
    INDEX idx_material_type (material_type),
    INDEX idx_class (classID),
    INDEX idx_site (siteID),
    INDEX idx_status (status),
    INDEX idx_outstanding (total_outstanding),
    INDEX idx_overdue (total_overdue),
    UNIQUE KEY unique_material_class_site (material_type, classID, siteID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Material master list for standardization
CREATE TABLE IF NOT EXISTS material_master (
    material_id INT AUTO_INCREMENT PRIMARY KEY,
    material_type VARCHAR(100) UNIQUE NOT NULL,
    material_name VARCHAR(255) NOT NULL,
    category VARCHAR(100) DEFAULT NULL,
    standard_unit VARCHAR(50) DEFAULT 'pieces',
    estimated_unit_cost DECIMAL(10,2) DEFAULT 0.00,
    description TEXT DEFAULT NULL,
    is_returnable TINYINT(1) DEFAULT 1,
    standard_return_period_days INT DEFAULT 30,
    status ENUM('Active', 'Discontinued') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_material_type (material_type),
    INDEX idx_category (category),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Insert sample sites for logistics system
INSERT IGNORE INTO sites (siteName, beneficiaries, Project_pathway, Category, province, sdp_id, latitude, longitude, address, contact_person, contact_phone, contact_email) VALUES 
('Johannesburg Training Center', 150, 'Construction', 'Urban', 'Gauteng', 1, -26.2041, 28.0473, '123 Main Street, Johannesburg', 'John Smith', '011-123-4567', 'john.smith@jtc.co.za'),
('Cape Town Skills Hub', 200, 'Hospitality', 'Urban', 'Western Cape', 1, -33.9249, 18.4241, '456 Long Street, Cape Town', 'Sarah Johnson', '021-987-6543', 'sarah.johnson@ctsh.co.za'),
('Durban Maritime Academy', 120, 'Maritime', 'Coastal', 'KwaZulu-Natal', 1, -29.8587, 31.0218, '789 Harbor Road, Durban', 'Mike Wilson', '031-555-0123', 'mike.wilson@dma.co.za'),
('Pretoria Technical Institute', 180, 'Engineering', 'Urban', 'Gauteng', 1, -25.7479, 28.2293, '321 University Road, Pretoria', 'Lisa Brown', '012-444-5678', 'lisa.brown@pti.co.za'),
('Port Elizabeth Industrial Park', 100, 'Manufacturing', 'Industrial', 'Eastern Cape', 1, -33.9608, 25.6022, '654 Industrial Avenue, Port Elizabeth', 'David Lee', '041-333-9876', 'david.lee@peip.co.za');

-- Insert sample facilitators
INSERT IGNORE INTO facilitator (firstName, lastName, email, phone, id_number, qualification, status, hire_date) VALUES 
('James', 'Anderson', 'james.anderson@facilitator.com', '082-111-2222', '8001015009088', 'Construction Management Diploma', 'Active', '2023-01-15'),
('Maria', 'Garcia', 'maria.garcia@facilitator.com', '083-333-4444', '8505234567089', 'Hospitality Management Certificate', 'Active', '2023-02-20'),
('Robert', 'Taylor', 'robert.taylor@facilitator.com', '084-555-6666', '7809123456087', 'Maritime Operations Certificate', 'Active', '2023-03-10'),
('Jennifer', 'Davis', 'jennifer.davis@facilitator.com', '085-777-8888', '9002145678090', 'Engineering Technology Diploma', 'Active', '2023-04-05'),
('Michael', 'Thompson', 'michael.thompson@facilitator.com', '086-999-0000', '8712098765086', 'Manufacturing Processes Certificate', 'Active', '2023-05-12');

-- Insert sample classes
INSERT IGNORE INTO class (className, siteID, facilitator_id, startDate, endDate, status, max_learners, qualification_id, description) VALUES 
('Construction Basics 2024-A', 1, 1, '2024-01-15', '2024-06-15', 'Active', 30, 1, 'Basic construction skills and safety training'),
('Hospitality Service Excellence', 2, 2, '2024-02-01', '2024-07-01', 'Active', 25, 2, 'Customer service and hospitality management'),
('Maritime Safety Operations', 3, 3, '2024-03-01', '2024-08-01', 'Active', 20, 3, 'Maritime safety protocols and operations'),
('Engineering Fundamentals', 4, 4, '2024-04-01', '2024-09-01', 'Active', 35, 4, 'Basic engineering principles and applications'),
('Manufacturing Quality Control', 5, 5, '2024-05-01', '2024-10-01', 'Active', 28, 5, 'Quality control processes in manufacturing');

-- Insert sample material inventory
INSERT IGNORE INTO material_inventory (material_name, material_code, category, unit_of_measure, current_stock, minimum_stock, maximum_stock, unit_cost, supplier, description) VALUES 
('Safety Helmets', 'HELM-001', 'Safety Equipment', 'pieces', 150, 20, 500, 45.00, 'SafetyFirst Suppliers', 'Standard construction safety helmets'),
('Work Gloves', 'GLOVE-001', 'Safety Equipment', 'pairs', 200, 30, 800, 12.50, 'SafetyFirst Suppliers', 'Heavy-duty work gloves'),
('Measuring Tapes', 'TAPE-001', 'Tools', 'pieces', 50, 10, 200, 25.00, 'ToolMaster Ltd', '5-meter measuring tapes'),
('Training Manuals', 'MANUAL-001', 'Educational', 'books', 300, 50, 1000, 35.00, 'EduBooks Publishing', 'Comprehensive training manuals'),
('First Aid Kits', 'AID-001', 'Safety Equipment', 'kits', 75, 15, 300, 85.00, 'MedSupply Co', 'Complete first aid kits'),
('Laptops', 'LAPTOP-001', 'Technology', 'pieces', 25, 5, 100, 8500.00, 'TechWorld', 'Training laptops for digital skills'),
('Projectors', 'PROJ-001', 'Technology', 'pieces', 10, 2, 50, 12000.00, 'TechWorld', 'Classroom projectors'),
('Uniforms', 'UNIFORM-001', 'Clothing', 'sets', 180, 25, 600, 120.00, 'WorkWear Solutions', 'Standard training uniforms');

-- Add logistics role permissions
INSERT IGNORE INTO account_user (account_name, username, email, password, role, sdp_id) VALUES 
('Logistics Manager', 'logistics', 'logistics@example.com', MD5('logistics123'), 'logistics', 1),
('Logistics Officer', 'logistics_officer', 'logistics.officer@example.com', MD5('logistics123'), 'logistics', 1),
('Material Coordinator', 'material_coord', 'material.coord@example.com', MD5('logistics123'), 'logistics', 1),
('Site Supervisor', 'site_supervisor', 'site.supervisor@example.com', MD5('logistics123'), 'logistics', 1),
('Inventory Manager', 'inventory_mgr', 'inventory.manager@example.com', MD5('logistics123'), 'logistics', 1);

-- Create logistics dashboard summary view
CREATE OR REPLACE VIEW logistics_dashboard_summary AS
SELECT 
    (SELECT COUNT(*) FROM sites WHERE status = 'Active') as active_sites,
    
    (SELECT COUNT(*) FROM class WHERE status = 'Active') as active_classes,
    (SELECT COUNT(*) FROM material_inventory WHERE status = 'Active') as total_materials,
    (SELECT COUNT(*) FROM material_inventory WHERE current_stock <= minimum_stock) as low_stock_items,
    (SELECT COUNT(*) FROM material_issuances WHERE status = 'Issued') as active_issuances,
    (SELECT COUNT(*) FROM material_issuances WHERE status = 'Overdue') as overdue_returns,
    (SELECT SUM(current_stock * unit_cost) FROM material_inventory WHERE status = 'Active') as total_inventory_value;

-- Create material stock alerts view
CREATE OR REPLACE VIEW material_stock_alerts AS
SELECT 
    inventory_id,
    material_name,
    material_code,
    current_stock,
    minimum_stock,
    (minimum_stock - current_stock) as shortage_quantity,
    CASE 
        WHEN current_stock = 0 THEN 'OUT_OF_STOCK'
        WHEN current_stock <= minimum_stock THEN 'LOW_STOCK'
        ELSE 'ADEQUATE'
    END as alert_level
FROM material_inventory 
WHERE current_stock <= minimum_stock AND status = 'Active'
ORDER BY alert_level DESC, shortage_quantity DESC;

-- Create overdue materials view
CREATE OR REPLACE VIEW overdue_materials AS
SELECT 
    mi.issuance_id,
    mi.material_id,
    inv.material_name,
    inv.material_code,
    mi.classID,
    c.className,
    mi.siteID,
    s.siteName,
    mi.facilitator_name,
    mi.recipient_name,
    mi.quantity_issued,
    mi.issue_date,
    mi.expected_return_date,
    DATEDIFF(CURDATE(), mi.expected_return_date) as days_overdue
FROM material_issuances mi
LEFT JOIN material_inventory inv ON mi.material_id = inv.inventory_id
LEFT JOIN class c ON mi.classID = c.classID
LEFT JOIN sites s ON mi.siteID = s.siteID
WHERE mi.status = 'Issued' 
AND mi.expected_return_date < CURDATE()
ORDER BY days_overdue DESC;