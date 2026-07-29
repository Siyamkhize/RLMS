# 🚀 FLUTTER GAP CLOSURE IMPLEMENTATION PLAN

**Date:** July 22, 2026  
**Status:** Ready to implement Flutter UI for Electrician and Plumber  
**Current Task:** Task 7 - Implement Gap Closure UI

---

## ✅ CURRENT STATUS

### Backend Status:
- ✅ Verification script working perfectly on production
- ✅ Shows 35 records for Bricklayer/Plumber (qual 65409)
- ✅ Shows 22 records for Electrician (qual 91761)
- ⏳ 4 PHP endpoint files ready but NOT uploaded yet
- ⏳ 2 SQL scripts ready but NOT run yet

### Frontend Status:
- ✅ Bricklayer gap closure working perfectly
- ⏳ Electrician gap closure NOT implemented
- ⏳ Plumber gap closure NOT implemented
- ✅ Config.dart already has endpoint URLs

---

## 🎯 IMPLEMENTATION APPROACH

We will implement gap closure dynamically in `ArplToolkitViewerPage.dart` to handle all three trades:

1. **Detect Trade** from learner/class data
2. **Load appropriate unit standards** based on trade
3. **Show/hide gap closure UI** based on "Recommended for Gap Closure" selection
4. **Save to correct backend** based on trade

---

## 📋 TRADE DETECTION LOGIC

### Trade Detection Strategy:

```dart
String _detectTrade() {
  // Option 1: From OFO Code (most reliable)
  if (widget.ofoCode == '671101') return 'electrician';
  if (widget.ofoCode == '642601') return 'plumber';
  if (widget.ofoCode == '641201') return 'bricklayer';
  
  // Option 2: From Trade Name (fallback)
  String tradeLower = (widget.trade ?? '').toLowerCase();
  if (tradeLower.contains('electric')) return 'electrician';
  if (tradeLower.contains('plumb')) return 'plumber';
  if (tradeLower.contains('brick')) return 'bricklayer';
  
  // Default
  return 'bricklayer';
}
```

### Trade Configuration:

```dart
Map<String, dynamic> _getTradeConfig(String trade) {
  switch (trade) {
    case 'electrician':
      return {
        'qualificationId': 91761,
        'ofoCode': '671101',
        'getEndpoint': Config.getElectricianGapUnitStandards,
        'saveEndpoint': Config.saveElectricianGapClosure,
        'displayName': 'Electrician',
      };
    case 'plumber':
      return {
        'qualificationId': 65409,
        'ofoCode': '642601',
        'getEndpoint': Config.getPlumberGapUnitStandards,
        'saveEndpoint': Config.savePlumberGapClosure,
        'displayName': 'Plumber',
      };
    case 'bricklayer':
    default:
      return {
        'qualificationId': 65409,
        'ofoCode': '641201',
        'getEndpoint': Config.getBricklayerGapUnitStandards,
        'saveEndpoint': Config.saveBricklayerGapClosure,
        'displayName': 'Bricklayer',
      };
  }
}
```

---

## 🔧 IMPLEMENTATION STEPS

### Step 1: Update ArplToolkitViewerPage.dart

**A. Add State Variables (around line 100)**

```dart
// Gap Closure State
bool _showGapClosureUI = false;
bool _isLoadingGapStandards = false;
List<Map<String, dynamic>> _availableUnitStandards = [];
List<String> _selectedUnitStandardIds = [];
String _detectedTrade = 'bricklayer';
Map<String, dynamic> _tradeConfig = {};
```

**B. Initialize Trade Detection (in initState)**

```dart
@override
void initState() {
  super.initState();
  _detectedTrade = _detectTrade();
  _tradeConfig = _getTradeConfig(_detectedTrade);
  // ... existing initState code
}
```

**C. Add Gap Closure Methods**

```dart
/// Detect trade from learner/class data
String _detectTrade() {
  // Implementation as shown above
}

/// Get trade-specific configuration
Map<String, dynamic> _getTradeConfig(String trade) {
  // Implementation as shown above
}

/// Load unit standards for gap closure
Future<void> _loadGapClosureUnitStandards() async {
  setState(() {
    _isLoadingGapStandards = true;
  });
  
  try {
    final response = await http.post(
      Uri.parse(_tradeConfig['getEndpoint']),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'learnerID': widget.learnerID,
        'qualification_id': _tradeConfig['qualificationId'],
      }),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          _availableUnitStandards = List<Map<String, dynamic>>.from(
            data['unit_standards'] ?? []
          );
          _selectedUnitStandardIds = List<String>.from(
            data['selected_unit_standards'] ?? []
          );
        });
      }
    }
  } catch (e) {
    print('Error loading gap closure unit standards: $e');
  } finally {
    setState(() {
      _isLoadingGapStandards = false;
    });
  }
}

/// Toggle unit standard selection
void _toggleUnitStandardSelection(String unitStandardId) {
  setState(() {
    if (_selectedUnitStandardIds.contains(unitStandardId)) {
      _selectedUnitStandardIds.remove(unitStandardId);
    } else {
      _selectedUnitStandardIds.add(unitStandardId);
    }
  });
}
```

**D. Handle Overall Result Selection Change**

When user selects "Recommended for Gap Closure" for ACRID 4 (Overall Result):

```dart
void _onOverallResultStatusChanged(String newStatus) {
  setState(() {
    _appendixHData['acrid_4_status'] = newStatus;
    
    // Show gap closure UI if "Recommended for Gap Closure" selected
    if (newStatus == 'Recommended for Gap Closure') {
      _showGapClosureUI = true;
      _loadGapClosureUnitStandards(); // Load unit standards
    } else {
      _showGapClosureUI = false;
      _selectedUnitStandardIds.clear();
    }
  });
}
```

**E. Add Gap Closure UI Section (after ACRID 4)**

```dart
// After Overall Result dropdown
if (_showGapClosureUI) ...[
  SizedBox(height: 24),
  _buildGapClosureSection(),
],
```

**F. Build Gap Closure UI Widget**

```dart
Widget _buildGapClosureSection() {
  return Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      border: Border.all(color: Colors.orange.shade300),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.school, color: Colors.orange.shade700),
            SizedBox(width: 8),
            Text(
              'Gap Closure Plan - ${_tradeConfig['displayName']}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade900,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'Select unit standards the learner needs to complete:',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        SizedBox(height: 16),
        
        if (_isLoadingGapStandards)
          Center(child: CircularProgressIndicator())
        else if (_availableUnitStandards.isEmpty)
          Text('No unit standards available', style: TextStyle(color: Colors.red))
        else
          _buildUnitStandardsList(),
        
        SizedBox(height: 16),
        _buildGapClosureSummary(),
      ],
    ),
  );
}

Widget _buildUnitStandardsList() {
  return Container(
    constraints: BoxConstraints(maxHeight: 400),
    child: ListView.builder(
      shrinkWrap: true,
      itemCount: _availableUnitStandards.length,
      itemBuilder: (context, index) {
        final standard = _availableUnitStandards[index];
        final standardId = standard['unit_standard_id'].toString();
        final isSelected = _selectedUnitStandardIds.contains(standardId);
        
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          elevation: isSelected ? 4 : 1,
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          child: CheckboxListTile(
            title: Text(
              standard['unit_standard_name'] ?? 'Unknown',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              'ID: $standardId | Credits: ${standard['credits'] ?? 0}',
              style: TextStyle(fontSize: 12),
            ),
            value: isSelected,
            onChanged: (bool? value) {
              _toggleUnitStandardSelection(standardId);
            },
            activeColor: Colors.blue,
          ),
        );
      },
    ),
  );
}

Widget _buildGapClosureSummary() {
  return Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.blue.shade300),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Selected Unit Standards:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${_selectedUnitStandardIds.length} / ${_availableUnitStandards.length}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
      ],
    ),
  );
}
```

**G. Update Save Function**

Add selected unit standards to save request:

```dart
Future<void> _saveAppendixHData() async {
  // ... existing validation ...
  
  // Prepare recommendations data
  final recommendations = [
    {'acrid': 1, 'status': _appendixHData['acrid_1_status'], 'remarks': _appendixHData['acrid_1_remarks']},
    {'acrid': 2, 'status': _appendixHData['acrid_2_status'], 'remarks': _appendixHData['acrid_2_remarks']},
    {'acrid': 3, 'status': _appendixHData['acrid_3_status'], 'remarks': _appendixHData['acrid_3_remarks']},
    {'acrid': 4, 'status': _appendixHData['acrid_4_status'], 'remarks': _appendixHData['acrid_4_remarks']},
  ];
  
  // Call appropriate save endpoint based on trade
  final response = await http.post(
    Uri.parse(_tradeConfig['saveEndpoint']),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'learnerID': widget.learnerID,
      'recommendations': recommendations,
      'selected_unit_standards': _selectedUnitStandardIds,
      'ofo_code': _tradeConfig['ofoCode'],
      'trade': _detectedTrade,
    }),
  );
  
  // ... handle response ...
}
```

---

## 🎨 UI FLOW

### User Experience:

1. **Assessor Opens Appendix H**
   - System detects trade (Electrician/Plumber/Bricklayer)
   - Shows trade name in UI

2. **Assessor Rates 4 Components**
   - Portfolio of Evidence
   - Interview
   - Practical Assessment
   - Overall Result

3. **User Selects "Recommended for Gap Closure" for Overall Result**
   - Gap closure section appears with orange background
   - Shows "Gap Closure Plan - [Trade Name]"
   - Loads unit standards automatically

4. **User Selects Unit Standards**
   - Checkboxes for each unit standard
   - Shows count: "5 / 22 selected"
   - Selected items highlighted in blue

5. **User Clicks Save**
   - Saves all 4 recommendations
   - Saves selected unit standards
   - Shows success message

---

## 📱 TESTING PLAN

### Test Scenarios:

**Scenario 1: Electrician**
- Learner with OFO 671101
- Should show "Gap Closure Plan - Electrician"
- Should load 22 unit standards
- Should save to `arplelectrician_gap_unit_standards`

**Scenario 2: Plumber**
- Learner with OFO 642601
- Should show "Gap Closure Plan - Plumber"
- Should load 35 unit standards (same as Bricklayer)
- Should save to `arplplumber_gap_unit_standards`

**Scenario 3: Bricklayer**
- Learner with OFO 641201
- Should show "Gap Closure Plan - Bricklayer"
- Should load 35 unit standards
- Should save to `arplbricklayer_gap_unit_standards` (existing)

**Edge Cases:**
- User changes from "Recommended for Gap Closure" to "Not Ready" → Gap UI should disappear
- User selects unit standards then changes status → Selections should be cleared
- Network error while loading standards → Show error message
- No unit standards available → Show "No unit standards available"

---

## 🚀 DEPLOYMENT STEPS

### Step 1: Implement Flutter UI
- [ ] Update `ArplToolkitViewerPage.dart` with gap closure logic
- [ ] Add trade detection
- [ ] Add gap closure UI widgets
- [ ] Update save function

### Step 2: Upload Backend Files
- [ ] Upload 4 PHP files to `/mobile/`
- [ ] Run 2 SQL scripts in phpMyAdmin
- [ ] Test endpoints manually

### Step 3: Build and Test APK
- [ ] Build release APK
- [ ] Install on test device
- [ ] Test with Electrician learner
- [ ] Test with Plumber learner
- [ ] Test with Bricklayer learner (verify still works)

### Step 4: Production Deployment
- [ ] Deploy APK to production
- [ ] Monitor for errors
- [ ] User acceptance testing

---

## 📞 NEXT ACTIONS

**Immediate:**
1. Implement Flutter UI changes in `ArplToolkitViewerPage.dart`
2. Test compilation
3. Review changes

**After UI Implementation:**
1. Upload backend PHP files
2. Run SQL scripts
3. Build APK
4. Test end-to-end workflow

---

**Status:** Ready to proceed with Flutter implementation!  
**Priority:** HIGH - Backend verified working, just needs UI implementation

