# Backend API Endpoints Used by SDP Learners System

## 📋 Overview
This document lists all the backend PHP pages/endpoints that are used by the SDP Learners system, organized by functionality.

## 🔍 SDP Learners Search & Data Retrieval

### 1. **get_sdp_learners_paginated.php**
- **Purpose**: Main API for fetching SDP learners with pagination
- **Used by**: `lib/sdp_learners_page_paginated.dart`
- **Features**: 
  - Pagination support (page, limit)
  - Search functionality
  - Site and class filtering
  - Surname sorting
- **Parameters**: `sdp_id`, `sdp_name`, `page`, `limit`, `search`, `site`, `class`

### 2. **get_sdp_learners_autocomplete.php**
- **Purpose**: Smart search autocomplete suggestions
- **Used by**: `lib/sdp_learners_page_paginated.dart`
- **Features**:
  - Real-time search suggestions
  - ID number and name matching
  - Smart ordering (ID matches first)
- **Parameters**: `sdp_id`, `sdp_name`, `search`, `limit`

### 3. **get_sdp_learners_paginated_smart.php**
- **Purpose**: Enhanced smart search with better performance
- **Used by**: Advanced search scenarios
- **Features**: Optimized queries, better caching

## 👥 Learner Management

### 4. **get_learners.php**
- **Purpose**: General learner data retrieval
- **Used by**: Various pages for learner information
- **Features**: Basic learner details, class information

### 5. **get_learners_optimized.php**
- **Purpose**: Performance-optimized learner retrieval
- **Used by**: High-traffic scenarios
- **Features**: Cached results, indexed queries

### 6. **get_learners_fast.php**
- **Purpose**: Fast learner lookup
- **Used by**: Quick searches and lookups
- **Features**: Minimal data transfer, fast response

### 7. **get_learners_search_optimized.php**
- **Purpose**: Optimized search functionality
- **Used by**: Search operations
- **Features**: Full-text search, performance optimized

## 🏢 Site & Class Management

### 8. **get_classes.php**
- **Purpose**: Retrieve class information
- **Used by**: Class selection dropdowns
- **Features**: Class details, site associations

### 9. **get_admin_sites.php**
- **Purpose**: Admin site management
- **Used by**: Admin role users
- **Features**: Site administration data

### 10. **get_tqa_sites.php**
- **Purpose**: TQA (Training Quality Assurance) sites
- **Used by**: TQA role users
- **Features**: TQA-specific site data

### 11. **get_logistics_sites.php**
- **Purpose**: Logistics site information
- **Used by**: Logistics role users
- **Features**: Logistics-specific site data

### 12. **get_logistics_sites_fixed.php**
- **Purpose**: Fixed version of logistics sites
- **Used by**: Logistics system (bug-fixed version)
- **Features**: Corrected data retrieval

## 📚 Learning Materials & Forms

### 13. **get_learner_checkbox_status.php**
- **Purpose**: Checkbox status for learner forms
- **Used by**: Material issuance forms
- **Features**: Form state management

### 14. **get_learner_material_status.php**
- **Purpose**: Material issuance status
- **Used by**: Material tracking
- **Features**: Status tracking, completion data

### 15. **save_learner_material_issue.php**
- **Purpose**: Save material issuance records
- **Used by**: Material issuance forms
- **Features**: Form submission, data validation

### 16. **get_material_inventory.php**
- **Purpose**: Material inventory management
- **Used by**: Logistics material pages
- **Features**: Stock levels, availability

### 17. **get_material_issuances.php**
- **Purpose**: Material issuance history
- **Used by**: Material tracking pages
- **Features**: Issuance records, history

### 18. **save_material_issuance.php**
- **Purpose**: Save material issuance data
- **Used by**: Material forms
- **Features**: Data persistence, validation

## 👨‍🏫 Facilitator Management

### 19. **getFacilitatordetails.php**
- **Purpose**: Facilitator information retrieval
- **Used by**: Facilitator-related pages
- **Features**: Facilitator profiles, details

### 20. **getFacilitatorDetailsForMaterials.php**
- **Purpose**: Facilitator details for material issuance
- **Used by**: Material issuance workflows
- **Features**: Facilitator-specific material data

### 21. **get_facilitator_checkbox_status.php**
- **Purpose**: Facilitator form checkbox status
- **Used by**: Facilitator forms
- **Features**: Form state management

### 22. **get_facilitator_material_status.php**
- **Purpose**: Facilitator material status
- **Used by**: Facilitator material pages
- **Features**: Material assignment status

### 23. **save_facilitator.php**
- **Purpose**: Save facilitator data
- **Used by**: Facilitator profile forms
- **Features**: Profile updates, data validation

### 24. **save_facilitator_profile.php**
- **Purpose**: Save facilitator profile information
- **Used by**: Profile management
- **Features**: Profile data persistence

### 25. **save_facilitator_material_issue.php**
- **Purpose**: Save facilitator material issuance
- **Used by**: Material issuance forms
- **Features**: Material assignment tracking

### 26. **get_facilitator_profile.php**
- **Purpose**: Retrieve facilitator profile
- **Used by**: Profile display pages
- **Features**: Complete profile data

## 📊 Logistics System

### 27. **get_logistics_learners.php**
- **Purpose**: Learners for logistics role
- **Used by**: Logistics dashboard
- **Features**: Logistics-specific learner data

### 28. **get_logistics_classes.php**
- **Purpose**: Classes for logistics management
- **Used by**: Logistics class pages
- **Features**: Class management data

### 29. **get_logistics_facilitators.php**
- **Purpose**: Facilitators in logistics system
- **Used by**: Logistics facilitator pages
- **Features**: Facilitator logistics data

## 📄 POE (Portfolio of Evidence) System

### 30. **get_poe.php**
- **Purpose**: POE document retrieval
- **Used by**: POE management pages
- **Features**: POE document data

### 31. **get_poe_documents.php**
- **Purpose**: POE document listing
- **Used by**: Document management
- **Features**: Document metadata, status

### 32. **get_poe_collection_status.php**
- **Purpose**: POE collection status
- **Used by**: POE collection pages
- **Features**: Collection progress, status

### 33. **upload_poe_document.php**
- **Purpose**: POE document upload
- **Used by**: Document scanner/upload
- **Features**: File upload, validation

### 34. **poe_collection_submit.php**
- **Purpose**: POE collection submission
- **Used by**: POE submission workflow
- **Features**: Collection finalization

## 💰 Finance System

### 35. **get_finance_learners.php**
- **Purpose**: Learners for finance role
- **Used by**: Finance dashboard
- **Features**: Finance-specific learner data

### 36. **get_finance_classes.php**
- **Purpose**: Classes for finance management
- **Used by**: Finance class pages
- **Features**: Financial class data

### 37. **save_learner_attendance.php**
- **Purpose**: Save attendance records
- **Used by**: Attendance tracking
- **Features**: Attendance data persistence

### 38. **get_learner_attendance.php**
- **Purpose**: Retrieve attendance data
- **Used by**: Attendance calendar
- **Features**: Attendance history, records

### 39. **upload_learner_register.php**
- **Purpose**: Upload learner register documents
- **Used by**: Finance register system
- **Features**: Document upload, processing

## 🔐 Authentication & Security

### 40. **login.php**
- **Purpose**: User authentication
- **Used by**: Login system
- **Features**: Multi-role authentication, session management

### 41. **check_account_password.php**
- **Purpose**: Password verification
- **Used by**: Login validation
- **Features**: Secure password checking

### 42. **check_finance_role.php**
- **Purpose**: Finance role verification
- **Used by**: Role-based access control
- **Features**: Role validation

## 📈 Marking & Assessment

### 43. **save_marks.php**
- **Purpose**: Save assessment marks
- **Used by**: Assessment forms
- **Features**: Mark recording, validation

### 44. **update_marks.php**
- **Purpose**: Update existing marks
- **Used by**: Mark editing functionality
- **Features**: Mark modification, audit trail

### 45. **get_logbook_marks.php**
- **Purpose**: Retrieve logbook marks
- **Used by**: Logbook display
- **Features**: Mark retrieval, formatting

### 46. **save_logbook_marks.php**
- **Purpose**: Save logbook assessment marks
- **Used by**: Logbook marking
- **Features**: Logbook mark persistence

### 47. **get_logbook_unit_standards.php**
- **Purpose**: Unit standards for logbook
- **Used by**: Logbook assessment
- **Features**: Unit standard data

### 48. **save_comment.php**
- **Purpose**: Save assessment comments
- **Used by**: Comment functionality
- **Features**: Comment persistence, updates

## 🕐 Time & Attendance

### 49. **get_clocking_days_count.php**
- **Purpose**: Count clocking days
- **Used by**: Attendance tracking
- **Features**: Day counting, statistics

## 🔍 Search & Optimization

### 50. **search_learner_by_id.php**
- **Purpose**: Search learner by ID number
- **Used by**: ID-based searches
- **Features**: Exact ID matching

### 51. **search_learner_cached.php**
- **Purpose**: Cached learner search
- **Used by**: Performance-optimized searches
- **Features**: Cached results, fast response

### 52. **search_autocomplete.php**
- **Purpose**: General autocomplete functionality
- **Used by**: Various search fields
- **Features**: Autocomplete suggestions

### 53. **cached_search_learners.php**
- **Purpose**: Cached learner search results
- **Used by**: High-performance search
- **Features**: Result caching, optimization

## 🔄 Data Synchronization

### 54. **sync_learners_fast.php**
- **Purpose**: Fast learner data synchronization
- **Used by**: Data sync operations
- **Features**: Efficient sync, minimal data transfer

## 🏗️ Work Experience

### 55. **get_work_experience.php**
- **Purpose**: Retrieve work experience data
- **Used by**: Work experience forms
- **Features**: Experience record retrieval

### 56. **save_work_experience.php**
- **Purpose**: Save work experience records
- **Used by**: Work experience forms
- **Features**: Experience data persistence

## 📋 Templates & Documents

### 57. **get_learner_templates.php**
- **Purpose**: Learner document templates
- **Used by**: Document generation
- **Features**: Template retrieval, formatting

### 58. **get_learner_documents.php**
- **Purpose**: Learner document listing
- **Used by**: Document management
- **Features**: Document metadata, access

## 🔧 Utility & Support

### 59. **learner.php**
- **Purpose**: General learner page/functionality
- **Used by**: Learner-related operations
- **Features**: General learner operations

### 60. **learnerDocument.php**
- **Purpose**: Learner document handling
- **Used by**: Document operations
- **Features**: Document processing

### 61. **update_learner.php**
- **Purpose**: Update learner information
- **Used by**: Learner editing
- **Features**: Data updates, validation

## 📊 Summary

**Total Backend Endpoints**: 61+ PHP files
**Main Categories**:
- 🔍 Search & Data Retrieval (8 files)
- 👥 Learner Management (4 files)  
- 🏢 Site & Class Management (5 files)
- 📚 Learning Materials (6 files)
- 👨‍🏫 Facilitator Management (8 files)
- 📊 Logistics System (3 files)
- 📄 POE System (5 files)
- 💰 Finance System (5 files)
- 🔐 Authentication (3 files)
- 📈 Marking & Assessment (6 files)
- 🔍 Search & Optimization (4 files)
- 🔄 Data Sync (1 file)
- 🏗️ Work Experience (2 files)
- 📋 Templates & Documents (2 files)
- 🔧 Utility & Support (3 files)

## 🌐 Base URL
All endpoints are accessed via: `https://rlms.rlms.co.za/mobile/[endpoint].php`

## 📝 Notes
- Most endpoints support both GET and POST methods
- All endpoints return JSON responses
- CORS headers are included for cross-origin requests
- Error handling and validation are implemented across all endpoints
- Many endpoints support pagination and filtering parameters