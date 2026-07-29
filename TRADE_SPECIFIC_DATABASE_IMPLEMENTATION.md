# Trade-Specific ARPL Database Implementation

**Date:** July 9, 2026  
**Scope:** Create separate database tables for Electrician, Bricklayer, and Plumber trades

---

## Architecture

### Current System
**Single set of tables for all trades:**
- `arpl_appendix_a` - all trades
- `arpl_appendix_b` - all trades
- `arpl_appendix_c` - all trades
- `arpl_appendix_d` - all trades
- `arpl_appendix_e` - all trades
- `arpl_appendix_f` - all trades
- `arpl_appendix_g` - all trades
- `arpl_appendix_h` - all trades
- `arpl_appendix_i` - all trades
- `arpl_appendix_j` - all trades

**Trade differentiation:** Via `ofoNumber` parameter in queries

### New System (Trade-Specific)
**Separate tables for each trade:**

```
Electrician (OFO 671101):
├── arpl_appendix_a_electrician
├── arpl_appendix_b_electrician
├── arpl_appendix_c_electrician
├── arpl_appendix_d_electrician
├── arpl_appendix_e_electrician
├── arpl_appendix_f_electrician
├── arpl_appendix_f_practical_tasks_electrician
├── arpl_appendix_f_workplace_observations_electrician
├── arpl_appendix_g_electrician
├── arpl_appendix_h_electrician
├── arpl_appendix_i_electrician
└── arpl_appendix_j_electrician

Bricklayer (OFO 671103):
├── arpl_appendix_a_bricklayer
├── arpl_appendix_b_bricklayer
├── arpl_appendix_c_bricklayer
├── arpl_appendix_d_bricklayer
├── arpl_appendix_e_bricklayer
├── arpl_appendix_f_bricklayer
├── arpl_appendix_f_practical_tasks_bricklayer
├── arpl_appendix_f_workplace_observations_bricklayer
├── arpl_appendix_g_bricklayer
├── arpl_appendix_h_bricklayer
├── arpl_appendix_i_bricklayer
└── arpl_appendix_j_bricklayer

Plumber (OFO 671102):
├── arpl_appendix_a_plumber
├── arpl_appendix_b_plumber
├── arpl_appendix_c_plumber
├── arpl_appendix_d_plumber
├── arpl_appendix_e_plumber
├── arpl_appendix_f_plumber
├── arpl_appendix_f_practical_tasks_plumber
├── arpl_appendix_f_workplace_observations_plumber
├── arpl_appendix_g_plumber
├── arpl_appendix_h_plumber
├── arpl_appendix_i_plumber
└── arpl_appendix_j_plumber
```

---

## Implementation Phases

### Phase 1: Database Migration
1. Create SQL migration scripts for Bricklayer tables
2. Create SQL migration scripts for Plumber tables
3. Execute migrations

### Phase 2: PHP API Updates
1. Create trade-specific data endpoints
2. Create trade-specific save endpoints
3. Update learner assignment to set OFO

### Phase 3: Dart Frontend
1. Create `ArplToolkitRouter.dart` - Route by OFO
2. Create `ArplToolkitElectricianPage.dart` - Queries electrician tables
3. Create `ArplToolkitBricklayerPage.dart` - Queries bricklayer tables
4. Create `ArplToolkitPlumberPage.dart` - Queries plumber tables

### Phase 4: Testing & Integration
1. Test data persistence
2. Test sync for each trade
3. Update offline database sync

---

## Database Table Schemas

### Tables to Create (Per Trade)

**1. arpl_appendix_a_[TRADE]** - Application Form
- Same schema as current
- Store candidate information

**2. arpl_appendix_b_[TRADE]** - Activities & Outcomes
- Same schema
- Trade-specific activities

**3. arpl_appendix_c_[TRADE]** - Curriculum Content
- Same schema
- Trade-specific curriculum

**4. arpl_appendix_d_[TRADE]** - Practical Criteria
- Same schema
- Trade-specific criteria

**5. arpl_appendix_e_[TRADE]** - Ratings
- Same schema
- Competency ratings

**6. arpl_appendix_f_[TRADE]** - Assessment Agreement
- Same schema
- Authorization data

**7. arpl_appendix_f_practical_tasks_[TRADE]** - Practical Tasks
- 13 rows per learner
- Trade-specific practical tasks

**8. arpl_appendix_f_workplace_observations_[TRADE]** - Workplace
- 13 rows per learner
- Trade-specific observations

**9. arpl_appendix_g_[TRADE]** - Observation Schedule
- Same schema
- Schedule data

**10. arpl_appendix_h_[TRADE]** - Recommendations
- Same schema
- Assessment recommendations

**11. arpl_appendix_i_[TRADE]** - Statement of Results
- Same schema
- Results data

**12. arpl_appendix_j_[TRADE]** - Pre-Assessment Agreement
- Same schema
- Agreement data

---

## Implementation Strategy

### Total Tables Needed
- Current: 12 tables (including practical & workplace observation)
- New Bricklayer: 12 tables
- New Plumber: 12 tables
- **Total: 36 tables**

### Creation Methods

#### Option 1: SQL Scripts (Recommended)
✅ **Advantages:**
- Version controlled
- Easy to replicate
- Can be run on demand
- Professional approach

**Files to Create:**
- `create_arpl_bricklayer_tables.sql`
- `create_arpl_plumber_tables.sql`

#### Option 2: Manual Creation
❌ **Disadvantages:**
- Error-prone
- Hard to track changes
- Not repeatable

---

## PHP API Layer Strategy

### Current Endpoints
```
GET  /mobile/get_arpl_toolkit_data.php?learnerID=X&ofoNumber=671101
POST /mobile/save_arpl_appendix_*.php
```

### New Approach: Trade-Aware Endpoints
```
GET  /mobile/get_arpl_toolkit_data.php?learnerID=X&ofoNumber=671101&trade=electrician
POST /mobile/save_arpl_appendix_a.php?trade=electrician
```

**Logic:**
1. Extract `trade` parameter from OFO number
2. Query appropriate trade-specific table
3. Return trade-specific data

**Mapping Function (PHP):**
```php
function getTradeName($ofoNumber) {
    $trades = [
        '671101' => 'electrician',
        '671102' => 'plumber',
        '671103' => 'bricklayer'
    ];
    return $trades[$ofoNumber] ?? 'electrician';
}

function getTableName($appendix, $trade) {
    return "arpl_appendix_{$appendix}_{$trade}";
}
```

---

## Dart Implementation Strategy

### Trade Router Page
```dart
// ArplToolkitRouter.dart

class ArplToolkitRouter extends StatelessWidget {
  final int learnerID;
  final int classID;
  final String ofoNumber;
  
  const ArplToolkitRouter({
    required this.learnerID,
    required this.classID,
    required this.ofoNumber,
  });
  
  @override
  Widget build(BuildContext context) {
    switch (ofoNumber) {
      case '671101': // Electrician
        return ArplToolkitElectricianPage(...);
      case '671102': // Plumber
        return ArplToolkitPlumberPage(...);
      case '671103': // Bricklayer
        return ArplToolkitBricklayerPage(...);
      default:
        return ArplToolkitElectricianPage(...); // Default
    }
  }
}
```

### Trade-Specific Pages
Each page queries its own tables:

```dart
// ArplToolkitBricklayerPage.dart

class _ArplToolkitBricklayerPageState extends State<...> {
  Future<void> _loadToolkitData() async {
    // Query bricklayer-specific tables
    // POST to /mobile/get_arpl_toolkit_data.php?trade=bricklayer
    
    final response = await http.get(
      Uri.parse('${Config.apiUrl}/mobile/get_arpl_toolkit_data.php'
        '?learnerID=$learnerID'
        '&classID=$classID'
        '&ofoNumber=$ofoNumber'
        '&trade=bricklayer'),
    );
  }
  
  Future<void> _saveBricklayerData() async {
    // Save to bricklayer-specific tables
    // POST to /mobile/save_arpl_appendix_*.php?trade=bricklayer
  }
}
```

---

## SQL Migration Template

**File: create_arpl_bricklayer_tables.sql**

```sql
-- ===============================================
-- BRICKLAYER ARPL TABLES (OFO: 671103)
-- ===============================================

-- APPENDIX A: APPLICATION FORM
CREATE TABLE IF NOT EXISTS arpl_appendix_a_bricklayer (
  id INT AUTO_INCREMENT PRIMARY KEY,
  learnerID INT NOT NULL,
  name VARCHAR(255),
  -- ... [same columns as current arpl_appendix_a]
  UNIQUE KEY unique_learner (learnerID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- APPENDIX B: ACTIVITIES & OUTCOMES
CREATE TABLE IF NOT EXISTS arpl_appendix_b_bricklayer (
  id INT AUTO_INCREMENT PRIMARY KEY,
  learnerID INT NOT NULL,
  -- ... [same columns as current arpl_appendix_b]
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ... [Continue for all appendices]

-- APPENDIX F: PRACTICAL TASKS
CREATE TABLE IF NOT EXISTS arpl_appendix_f_practical_tasks_bricklayer (
  id INT AUTO_INCREMENT PRIMARY KEY,
  learnerID INT NOT NULL,
  rowNumber INT NOT NULL,
  taskName VARCHAR(255),
  -- ... [same columns as current]
  UNIQUE KEY unique_learner_row (learnerID, rowNumber)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- APPENDIX F: WORKPLACE OBSERVATIONS
CREATE TABLE IF NOT EXISTS arpl_appendix_f_workplace_observations_bricklayer (
  id INT AUTO_INCREMENT PRIMARY KEY,
  learnerID INT NOT NULL,
  -- ... [same columns as current]
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## Implementation Checklist

### Phase 1: Database
- [ ] Create `create_arpl_bricklayer_tables.sql`
- [ ] Create `create_arpl_plumber_tables.sql`
- [ ] Execute migrations
- [ ] Verify table creation

### Phase 2: PHP API
- [ ] Update `get_arpl_toolkit_data.php` for trade routing
- [ ] Update `save_arpl_appendix_*.php` for trade routing
- [ ] Create `get_trade_from_ofo.php` helper
- [ ] Test endpoints

### Phase 3: Dart
- [ ] Create `ArplToolkitRouter.dart`
- [ ] Create `ArplToolkitElectricianPage.dart` (copy current)
- [ ] Create `ArplToolkitBricklayerPage.dart` (new)
- [ ] Create `ArplToolkitPlumberPage.dart` (new)
- [ ] Update navigation to use router

### Phase 4: Testing
- [ ] Test Electrician workflow
- [ ] Test Bricklayer workflow
- [ ] Test Plumber workflow
- [ ] Test data persistence
- [ ] Test offline sync

---

## Data Migration Strategy

### Existing Electrician Data
Current data in `arpl_appendix_*` tables needs to stay there (backward compatible).

### New Learners
When a learner with OFO 671103 (Bricklayer) loads:
1. System checks OFO
2. Routes to bricklayer-specific tables
3. If no data exists, creates new records
4. Queries and saves to bricklayer tables only

---

## Naming Convention

**Pattern:** `arpl_appendix_[letter/number]_[trade]`

**Examples:**
- `arpl_appendix_a_electrician` - Electrician cover
- `arpl_appendix_f_practical_tasks_bricklayer` - Bricklayer practical
- `arpl_appendix_h_plumber` - Plumber recommendations

**Trades:**
- `electrician` (671101)
- `bricklayer` (671103)
- `plumber` (671102)

---

## Total Implementation Time

| Component | Time | Notes |
|-----------|------|-------|
| SQL Scripts | 15 min | Creating migration files |
| PHP Updates | 20 min | Trade routing in endpoints |
| Dart Pages | 30 min | 3 pages (router + 2 trades) |
| Testing | 30 min | All workflows |
| Build & Deploy | 20 min | Compile & test APK |
| **Total** | **~2 hours** | Complete implementation |

---

## Next Steps

1. **Create SQL migration scripts**
   - Duplicate current schema for each trade

2. **Update PHP endpoints**
   - Add trade parameter handling
   - Route to correct tables

3. **Create Dart pages**
   - Router (smart OFO-based routing)
   - Trade-specific viewers

4. **Test thoroughly**
   - All three trade workflows
   - Data persistence
   - Sync operations

5. **Deploy**
   - Database migrations
   - New APK with all features

---

**Ready to proceed?** Confirm and I'll start with Phase 1 (SQL migration scripts).

