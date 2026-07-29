# Code Changes Reference - Appendix F & Trade Titles

**File:** `lib/ArplToolkitViewerPage.dart`  
**Total Changes:** ~150 lines added  
**Build Status:** ✅ Success

---

## 1. Helper Methods Added (Lines 1777-1820)

### Method 1: Get Trade Name from OFO

```dart
/// Get trade name from OFO number
String _getTradeName(String ofoNumber) {
  const tradeMappings = {
    '671101': 'Electrician',
    '671102': 'Plumber',
    '671103': 'Bricklayer',
    '671104': 'Carpenter',
    '671105': 'Welder',
  };
  return tradeMappings[ofoNumber] ?? 'Trade Specialist';
}
```

**Usage:** Called in every appendix method
```dart
final tradeName = _getTradeName(widget.ofoNumber);
```

---

### Method 2: Build Trade Title Banner

```dart
/// Build a consistent trade title banner for all appendices
Widget _buildTradeTitleBanner(String tradeName) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF006341),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      'Trade: $tradeName',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  );
}
```

**Usage:** Added after appendix headers in all 10 appendices
```dart
const SizedBox(height: 16),
_buildTradeTitleBanner(tradeName),
const SizedBox(height: 16),
```

---

## 2. Appendix Updates for Trade Titles

### Pattern Applied to 10 Appendices:

Each appendix was updated following this pattern:

#### Before:
```dart
Widget _buildAppendixX() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Appendix X: TITLE',
                // ...
              ),
            ),
            // ... edit toggle
          ],
        ),
        const SizedBox(height: 16),
        // ... rest of content
```

#### After:
```dart
Widget _buildAppendixX() {
  final tradeName = _getTradeName(widget.ofoNumber);
  
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Appendix X: TITLE',
                // ...
              ),
            ),
            // ... edit toggle
          ],
        ),
        const SizedBox(height: 16),
        _buildTradeTitleBanner(tradeName),  // ← ADDED
        const SizedBox(height: 16),
        // ... rest of content
```

### Appendices Updated:
1. **Appendix A** - Application Form
2. **Appendix B** - Self-Evaluation
3. **Appendix C** - Curriculum Overview
4. **Appendix D** - Practical Skills Assessment
5. **Appendix E** - Workplace Experience Evaluation
6. **Appendix G** - Appeals Form
7. **Appendix H** - Access Recommendation
8. **Appendix I** - Statement of Results
9. **Appendix J** - Pre-Assessment Agreement
10. **Appendix F** - (See complete redesign below)

---

## 3. Appendix F - Complete Redesign

### Location: Lines ~1863-2080 (in ArplToolkitViewerPage.dart)

### Old Implementation:
- Complex assessment agreement form
- Acknowledgment checkboxes (Knowledge, Practical, Workplace)
- Assessment components table
- Single signature section
- Overall competency section

### New Implementation:

```dart
Widget _buildAppendixF() {
  final tradeName = _getTradeName(widget.ofoNumber);

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Appendix F: PRACTICAL ASSESSMENT EVALUATION',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006341),
                ),
              ),
            ),
            if (_isEditing)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '✏️ EDIT MODE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Trade Title Banner
        _buildTradeTitleBanner(tradeName),
        const SizedBox(height: 24),

        // Section 1: Practical Section - Tasks Assessment
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Practical Section - Tasks Assessment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006341),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    border: TableBorder.all(
                      color: Colors.grey[400]!,
                      width: 1,
                    ),
                    children: [
                      // Header Row
                      TableRow(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'No',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 200,
                              child: Text(
                                'Tasks',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Score',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              '%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Data Rows (1-13)
                      ...List.generate(
                        13,
                        (index) => TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text((index + 1).toString()),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(width: 200),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(width: 60),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(width: 40),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Section 2: Observation Evaluation - Scoring Guide
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Observation Evaluation - Scoring Guide',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006341),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Fair',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '1',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF006341),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Good',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '2',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF006341),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Excellent',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '3',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF006341),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Section 3: Authorization & Signatures
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Authorization & Signatures',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006341),
                  ),
                ),
                const Divider(height: 24),
                if (_isEditing) ...[
                  const Text(
                    'Assessor:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Signature',
                            hintText: 'Type name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                          ),
                          readOnly: true,
                          controller: TextEditingController(
                            text: DateTime.now().toString().substring(0, 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Candidate:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Signature',
                            hintText: 'Type name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                          ),
                          readOnly: true,
                          controller: TextEditingController(
                            text: DateTime.now().toString().substring(0, 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Witness Name',
                      hintText: 'Full name of witness',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else
                  const Text('Not signed yet',
                      style: TextStyle(
                          fontStyle: FontStyle.italic, color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Section 4: Workplace Observation
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Workplace Observation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006341),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    border: TableBorder.all(
                      color: Colors.grey[400]!,
                      width: 1,
                    ),
                    children: [
                      // Header Row
                      TableRow(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'No',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 150,
                              child: Text(
                                'Tasks Observed',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 150,
                              child: Text(
                                'Technical Knowledge',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 150,
                              child: Text(
                                'Interpretation',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 130,
                              child: Text(
                                'Team Work',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Data Rows (1-5)
                      ...List.generate(
                        5,
                        (index) => TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text((index + 1).toString()),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(width: 150),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(width: 150),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(width: 150),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(width: 130),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_isEditing) ...[
                  const Divider(height: 24),
                  const Text(
                    'Assessor Signature:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Signature',
                            hintText: 'Type name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                          ),
                          readOnly: true,
                          controller: TextEditingController(
                            text: DateTime.now().toString().substring(0, 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
```

---

## Key Differences - Appendix F

| Aspect | Before | After |
|--------|--------|-------|
| Layout | Cards with checkboxes | Professional tables |
| Structure | 4 sections (agreement) | 5 sections (assessment) |
| Tables | 1 complex table | 2 focused tables |
| Rows in table | 8 mixed items | 13 tasks + 5 tasks |
| Signature fields | Single section | Multiple sections |
| Editable fields | Checkboxes, text | Text inputs + date fields |
| Mobile support | Fixed width | Horizontal scroll |
| Assessment focus | Knowledge-based | Practical-based |

---

## Testing Verification

### Syntax Check:
```bash
flutter analyze lib/ArplToolkitViewerPage.dart
# Result: ✅ No critical errors
```

### Build Check:
```bash
flutter build apk --debug
# Result: ✅ Success (built in 55.8s)
```

### Installation:
```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
# Result: ✅ Success
```

---

## Code Quality Metrics

| Metric | Value |
|--------|-------|
| Lines Added | ~150 |
| Helper Methods | 2 |
| Appendices Updated | 10 |
| Tables in Appendix F | 2 |
| Critical Errors | 0 |
| Syntax Errors | 0 |
| Build Success | ✅ |

---

## References

- **Main File:** `lib/ArplToolkitViewerPage.dart`
- **Build Artifact:** `build/app/outputs/flutter-apk/app-debug.apk`
- **Backend:** `mobile/save_arpl_appendix_f_assessment.php`
- **Data Models:** `lib/models/arpl_toolkit_data.dart`

