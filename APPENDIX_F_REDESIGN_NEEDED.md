# Appendix F - Redesign Documentation

**Status:** Code structure ready, UI redesign needed  
**Date:** July 9, 2026  
**Priority:** High  

---

## Current State

The Appendix F implementation is currently a form-based assessment agreement. According to the images provided by the user, it needs to be redesigned to match the practical assessment evaluation form.

## Required Changes

### New Appendix F Structure (Based on User Images)

The form should display the following sections in order:

#### 1. **Header**
- Title: "Appendix F: PRACTICAL ASSESSMENT EVALUATION"
- Trade name badge (e.g., "Trade: Electrician")
- Edit mode toggle

#### 2. **Practical Section - Tasks Assessment** (Table 1)
- Columns: No | Tasks | Score | %
- Rows: 1-13 (numbered, with empty cells for assessment data)
- Scrollable horizontal table

#### 3. **Observation Evaluation** (Scoring Guide)
- Fair: 1
- Good: 2
- Excellent: 3

#### 4. **Authorization & Signatures**
- Assessor Signature: _____________ | Date: ___/___/20__
- Candidate section:
  - Signature: _____________ | Date: ___/___/20__
  - Witness: _________________________________

#### 5. **Workplace Observation** (Table 2)
- Columns: No | Tasks Observed | Technical knowledge | Interpretation of instruction | Team work attitude
- Rows: 1-5+ (for workplace observation data)
- Scrollable horizontal table
- Footer: Assessor Signature: _____________ | Date: _________________

---

## Implementation Notes

### Helper Methods Needed

```dart
// Build a table cell widget
Widget _buildTableCell(String text, bool isHeader, double width) {
  return SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 13 : 12,
        ),
      ),
    ),
  );
}

// Get trade name from OFO number
String _getTradeName(String ofoNumber) {
  switch (ofoNumber) {
    case '671101':
      return 'Electrician';
    // Add other trades as needed
    default:
      return 'Specialist';
  }
}
```

### Key CSS/Styling
- Table borders: Colors.grey[400]
- Header background: Colors.grey[300]
- Container background: Color(0xFF006341) for titles
- Card elevation for section grouping

---

## Files to Modify

- `lib/ArplToolkitViewerPage.dart` - Replace `_buildAppendixF()` method (currently lines 1859-2050+)
- Add helper methods: `_getTradeName()`, `_buildTableCell()`

---

## Testing Requirements

After implementation:
1. Build APK: `flutter build apk --debug`
2. Install on device
3. Navigate to Appendix F tab
4. Verify:
   - Trade name displays correctly for learner's OFO
   - Tables render with correct column counts
   - Scrollable horizontally on mobile devices
   - Edit mode can be toggled
   - All signature fields visible

---

## Notes

- The previous Appendix F implementation had complex card-based layout - this simplifies to practical assessment form
- Trade title now displays at top of all appendices (consistent branding)
- Tables use horizontal scrolling for mobile responsiveness
- Signature fields shown as text lines (matching scanned document format)

---

**Next Action:** Replace `_buildAppendixF()` with new implementation matching the images provided.
