# Facilitator Class Material Issuance System

## Overview

This system allows logistics personnel to issue materials directly to class facilitators for the entire class, rather than issuing materials to individual learners. This is more efficient for bulk material distribution.

## Key Features

- **Class-Level Issuance**: Materials are issued to the facilitator for the entire class
- **Cumulative Tracking**: Multiple issuances add to the total quantity
- **Separate Database**: Uses `facilitator_class_materials` table for dedicated tracking
- **Facilitator Focus**: Shows facilitator details and qualification information
- **Bulk Efficiency**: Issue multiple materials at once to one facilitator

## Files Created

### Flutter Widget
- `lib/facilitator_class_material_issue_page.dart` - Main Flutter page for class material issuance

### Backend API
- `save_facilitator_class_material_issue.php` - API endpoint for saving class material issuances

### Testing
- `test_facilitator_class_materials.php` - Test script to verify the system

## How to Use

### 1. Navigation to Class Material Issuance

Replace or add alongside the existing individual learner material issuance:

```dart
// Instead of navigating to individual learner material issuance
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => FacilitatorClassMaterialIssuePage(
      logisticsId: widget.logisticsId,
      logisticsName: widget.logisticsName,
      siteId: site['siteID'].toString(),
      siteName: site['siteName'],
      classId: classItem['classID'].toString(),
      className: classItem['className'],
    ),
  ),
);
```

### 2. Database Table Structure

The system automatically creates the `facilitator_class_materials` table:

```sql
CREATE TABLE facilitator_class_materials (
    id INT AUTO_INCREMENT PRIMARY KEY,
    classID INT NOT NULL,
    facilitator_full_name VARCHAR(255) NOT NULL,
    representative_full_name VARCHAR(255) NOT NULL,
    qualification_name VARCHAR(255),
    facilitator_signature TEXT,
    representative_signature TEXT,
    description VARCHAR(255) NOT NULL,
    sub_description VARCHAR(255),
    quantity INT NOT NULL DEFAULT 0,
    is_synced TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### 3. API Usage

The API endpoint accepts JSON data:

```json
{
    "classID": 1,
    "facilitatorFullName": "John Smith",
    "representativeFullName": "Logistics Manager",
    "description": "Safety Equipment Set",
    "subDescription": "Complete safety kit for construction training",
    "quantity": 25,
    "qualificationName": "Construction Safety Certificate",
    "facilitatorSignature": "",
    "representativeSignature": ""
}
```

## Workflow

1. **Logistics Login**: Logistics personnel log into the system
2. **Site Selection**: Choose the site containing the classes
3. **Class Selection**: Select the specific class for material issuance
4. **Facilitator Display**: System shows facilitator details for the class
5. **Material Selection**: Enter quantities for each material type
6. **Bulk Issuance**: Submit all materials at once to the facilitator
7. **Tracking**: System tracks cumulative quantities per facilitator per class

## Key Differences from Individual Learner System

| Aspect | Individual Learner System | Class Facilitator System |
|--------|---------------------------|--------------------------|
| **Target** | Individual learners in class | Class facilitator |
| **Scope** | Per learner quantities | Bulk class quantities |
| **Database** | `material_forms` table | `facilitator_class_materials` table |
| **Tracking** | By learner + material | By class + facilitator + material |
| **Efficiency** | Multiple entries per class | Single entry per material per class |
| **Use Case** | Individual distribution | Bulk distribution to facilitator |

## Benefits

1. **Efficiency**: Issue materials once per class instead of per learner
2. **Facilitator Responsibility**: Facilitator manages distribution to learners
3. **Bulk Tracking**: Better for large quantity materials
4. **Simplified Logistics**: Fewer individual transactions
5. **Class Management**: Aligns with class-based training structure

## Testing

Run the test script to verify the system:

```bash
# Access the test script in your browser
http://your-server/test_facilitator_class_materials.php
```

The test will:
- Verify API endpoint functionality
- Check database table creation
- Show table structure
- Display recent records
- Provide usage examples

## Integration with Existing System

This system can work alongside the existing individual learner material issuance system:

- Use **individual system** for personal items (ID cards, certificates)
- Use **class system** for bulk materials (textbooks, safety equipment, tools)
- Both systems can coexist and serve different purposes

## Future Enhancements

1. **Digital Signatures**: Add signature capture for facilitator and logistics
2. **Material Categories**: Group materials by type (safety, educational, tools)
3. **Approval Workflow**: Add approval steps for high-value materials
4. **Reporting**: Generate class material distribution reports
5. **Integration**: Link with inventory management systems