# ARPL Toolkit Dynamic PHP - Update Plan

## Objective
Update `mobile/arpl_toolkit_dynamic.php` to match the Flutter mobile app structure with:
1. All appendices in correct order (A through H)
2. Appendix H as the final tab (Access Recommendation)
3. Display all saved data from database for each appendix
4. Match the tab order in the mobile app

## Current Mobile App Tab Structure
Based on `lib/ArplAssessorPage.dart`:
1. **Appx A** - Application Form
2. **Appx B** - Self-Evaluation (Assessor rates 1-5)
3. **Appx C** - Trade Curriculum
4. **Appx D** - Practical Skills (Yes/No checkboxes)
5. **Appx E** - Workplace Experience (1-5 ratings + comments)
6. **Appx H** - Access Recommendation (NEW - last tab)

## Database Tables to Query

### Appendix B - Assessor Ratings
**Table**: `arplappxb_activity_ratings`
```sql
SELECT * FROM arplappxb_activity_ratings 
WHERE learnerID = ? AND ofo_number = ? AND assessor_id = ?
```
**Fields**: activity_id, activity_name, competency_scale_id (1-5), comments, rating_date

### Appendix D - Self-Evaluation  
**Table**: `arpl_appendix_d`
```sql
SELECT * FROM arpl_appendix_d 
WHERE learnerID = ? AND assessor_id = ? AND ofo_number = ?
```
**Fields**: activity_1 through activity_22 (values: 'yes', 'no', 'pending')

### Appendix E - Workplace Experience
**Table**: `arplappxe_electrician_activity_ratings`
```sql
SELECT * FROM arplappxe_electrician_activity_ratings 
WHERE learnerID = ? AND ofo_number = ? AND facilitator_id = ?
```
**Fields**: activity_id, activity_name, competency_scale_id (1-5), comments, rating_date

### Appendix H - Access Recommendation
**Tables**: 
- `appxh_acrelectrician` - Assessment items (4 items: Knowledge, Practical, Workplace, Overall)
- `arplelectrician_access_recommendation` - Saved recommendations
- `arpl_gap_analysis_unit_standards` - Gap closure learners + unit standards
- `arpl_trade_test_recommended` - Trade test ready learners

```sql
-- Get ACR items
SELECT * FROM appxh_acrelectrician WHERE qualification_id = 91761

-- Get saved recommendation
SELECT * FROM arplelectrician_access_recommendation 
WHERE learnerID = ? AND assessor_id = ?

-- Get gap analysis unit standards (if applicable)
SELECT * FROM arpl_gap_analysis_unit_standards 
WHERE learnerID = ?

-- Get trade test recommendation (if applicable)
SELECT * FROM arpl_trade_test_recommended 
WHERE learnerID = ?
```

## Required Changes to arpl_toolkit_dynamic.php

### 1. Add Data Loading Functions (after line ~200)

```php
// ── STEP 8 – LOAD APPENDIX B DATA ───────────────────────────
$appendixB_data = [];
$stmt = $conn->prepare("
    SELECT activity_id, activity_name, competency_scale_id, comments, rating_date
    FROM arplappxb_activity_ratings
    WHERE learnerID = ? AND ofo_number = ?
    ORDER BY activity_id
");
$stmt->bind_param('is', $learnerID, $ofo_number);
$stmt->execute();
$result = $stmt->get_result();
while ($row = $result->fetch_assoc()) {
    $appendixB_data[$row['activity_id']] = $row;
}
$stmt->close();

// ── STEP 9 – LOAD APPENDIX D DATA ───────────────────────────
$appendixD_data = null;
$stmt = $conn->prepare("
    SELECT * FROM arpl_appendix_d
    WHERE learnerID = ? AND ofo_number = ?
    LIMIT 1
");
$stmt->bind_param('is', $learnerID, $ofo_number);
$stmt->execute();
$result = $stmt->get_result();
$appendixD_data = $result->fetch_assoc();
$stmt->close();

// ── STEP 10 – LOAD APPENDIX E DATA ───────────────────────────
$appendixE_data = [];
$stmt = $conn->prepare("
    SELECT activity_id, activity_name, competency_scale_id, comments, rating_date
    FROM arplappxe_electrician_activity_ratings
    WHERE learnerID = ? AND ofo_number = ?
    ORDER BY activity_id
");
$stmt->bind_param('is', $learnerID, $ofo_number);
$stmt->execute();
$result = $stmt->get_result();
while ($row = $result->fetch_assoc()) {
    $appendixE_data[$row['activity_id']] = $row;
}
$stmt->close();

// ── STEP 11 – LOAD APPENDIX H DATA ───────────────────────────
// Get ACR items
$appendixH_items = [];
$stmt = $conn->prepare("SELECT * FROM appxh_acrelectrician WHERE qualification_id = 91761");
$stmt->execute();
$result = $stmt->get_result();
while ($row = $result->fetch_assoc()) {
    $appendixH_items[] = $row;
}
$stmt->close();

// Get saved recommendation
$appendixH_recommendation = null;
$stmt = $conn->prepare("
    SELECT * FROM arplelectrician_access_recommendation
    WHERE learnerID = ?
    LIMIT 1
");
$stmt->bind_param('i', $learnerID);
$stmt->execute();
$result = $stmt->get_result();
$appendixH_recommendation = $result->fetch_assoc();
$stmt->close();

// Get gap analysis unit standards if applicable
$appendixH_gap_standards = [];
if ($appendixH_recommendation && 
    ($appendixH_recommendation['overall_result'] === 'Recommended for gap closure')) {
    $stmt = $conn->prepare("
        SELECT gaus.*, ous.unit_standard_name
        FROM arpl_gap_analysis_unit_standards gaus
        LEFT JOIN occupational_unit_standards ous 
            ON gaus.unit_standard_id = ous.Module_Code
        WHERE gaus.learnerID = ?
    ");
    $stmt->bind_param('i', $learnerID);
    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = $result->fetch_assoc()) {
        $appendixH_gap_standards[] = $row;
    }
    $stmt->close();
}

// Check if recommended for trade test
$appendixH_trade_test = null;
$stmt = $conn->prepare("
    SELECT * FROM arpl_trade_test_recommended
    WHERE learnerID = ?
    LIMIT 1
");
$stmt->bind_param('i', $learnerID);
$stmt->execute();
$result = $stmt->get_result();
$appendixH_trade_test = $result->fetch_assoc();
$stmt->close();
```

### 2. Update Contents Table (around line ~400)

Add Appendix H to the contents:

```php
<tr><td>Appendix H: Access Recommendation</td><td class="c">25</td></tr>
```

### 3. Add Appendix B Section with Saved Data (after Appendix A)

```php
<!-- ═══════════════════════════════════════════
     APPENDIX B – ASSESSOR RATINGS (1-5 SCALE) with SAVED DATA
═══════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($qual_name) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br>642601</td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>6 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">3. Appendix B: ASSESSOR EVALUATION (1-5 Scale)
  <span style="font-size:10pt;font-weight:normal;">(Learner: <?= htmlspecialchars($fullname) ?>)</span>
</div>

<table class="ft">
  <tr>
    <th>No</th>
    <th class="l">Activity</th>
    <th>Rating (1-5)</th>
    <th class="l">Comments</th>
    <th>Date</th>
  </tr>
  <?php foreach ($activities as $num => $name): ?>
  <tr>
    <td class="c"><?= $num ?></td>
    <td><?= htmlspecialchars($name) ?></td>
    <td class="c">
      <?php if (isset($appendixB_data[$num])): ?>
        <strong style="color:#006341;"><?= $appendixB_data[$num]['competency_scale_id'] ?></strong>
      <?php else: ?>
        <input type="number" min="1" max="5" style="width:50px;">
      <?php endif; ?>
    </td>
    <td>
      <?php if (isset($appendixB_data[$num]) && $appendixB_data[$num]['comments']): ?>
        <span class="prefilled"><?= htmlspecialchars($appendixB_data[$num]['comments']) ?></span>
      <?php else: ?>
        <input type="text" placeholder="Comments">
      <?php endif; ?>
    </td>
    <td class="c">
      <?php if (isset($appendixB_data[$num])): ?>
        <small><?= date('Y-m-d', strtotime($appendixB_data[$num]['rating_date'])) ?></small>
      <?php endif; ?>
    </td>
  </tr>
  <?php endforeach; ?>
</table>
</div>
```

### 4. Update Appendix D Section with Saved Data

Replace the current Appendix D section to show saved yes/no data from database.

### 5. Update Appendix E Section with Saved Data

Show ratings and comments from `arplappxe_electrician_activity_ratings` table.

### 6. Add Appendix H Section (NEW - Last Appendix)

```php
<!-- ═══════════════════════════════════════════
     APPENDIX H – ACCESS RECOMMENDATION (NEW)
═══════════════════════════════════════════ -->
<div class="pb">
<table class="dht">
  <tr><td><b>Document</b><br>ARPLTOOLKIT</td><td><b>Trade</b><br><?= htmlspecialchars($qual_name) ?></td><td><b>Trade Test Centre</b><br><?= htmlspecialchars($ctx['provider_name'] ?? '') ?></td></tr>
  <tr><td><b>Version</b><br>1/2019</td><td><b>OFO code</b><br>642601</td><td><b>Accreditation no</b><br><?= htmlspecialchars($ctx['accreditation_n'] ?? '') ?></td></tr>
  <tr><td><b>AQP</b><br>NAMB</td><td><b>Page</b><br>25 of 30</td><td><b>Date revised</b><br><?= $today ?></td></tr>
</table>

<div class="sec-title">8. Appendix H: ACCESS RECOMMENDATION SYSTEM
  <span style="font-size:10pt;font-weight:normal;">(Learner: <?= htmlspecialchars($fullname) ?>)</span>
</div>

<p style="font-size:11pt;margin-bottom:10px;">
  <b>Assessment Summary:</b> Based on evaluations in Appendices B, D, and E, determine readiness for trade test or gap closure requirements.
</p>

<table class="ft">
  <tr>
    <th>No</th>
    <th class="l">Assessment Component</th>
    <th>Status/Result</th>
  </tr>
  <?php foreach ($appendixH_items as $idx => $item): ?>
  <tr>
    <td class="c"><?= $item['ACRID'] ?></td>
    <td><b><?= htmlspecialchars($item['assessment_item']) ?></b></td>
    <td>
      <?php if ($appendixH_recommendation): ?>
        <?php
        $field = '';
        switch($item['ACRID']) {
            case 1: $field = 'knowledge_assessment'; break;
            case 2: $field = 'practical_assessment'; break;
            case 3: $field = 'workplace_observation'; break;
            case 4: $field = 'overall_result'; break;
        }
        ?>
        <span class="prefilled" style="font-weight:bold;color:#006341;">
          <?= htmlspecialchars($appendixH_recommendation[$field] ?? 'Not set') ?>
        </span>
      <?php else: ?>
        <input type="text" placeholder="Not yet assessed">
      <?php endif; ?>
    </td>
  </tr>
  <?php endforeach; ?>
</table>

<?php if ($appendixH_recommendation): ?>
  
  <?php if ($appendixH_recommendation['overall_result'] === 'Recommended for gap closure' && !empty($appendixH_gap_standards)): ?>
    <div class="sec-sub" style="margin-top:20px;">Gap Closure - Unit Standards Assigned</div>
    <table class="ft">
      <tr><th>Unit Standard ID</th><th class="l">Unit Standard Name</th><th>Date Assigned</th></tr>
      <?php foreach ($appendixH_gap_standards as $std): ?>
      <tr>
        <td class="c"><?= htmlspecialchars($std['unit_standard_id']) ?></td>
        <td><?= htmlspecialchars($std['unit_standard_name'] ?? 'N/A') ?></td>
        <td class="c"><?= date('Y-m-d', strtotime($std['assigned_date'])) ?></td>
      </tr>
      <?php endforeach; ?>
    </table>
  <?php endif; ?>

  <?php if ($appendixH_trade_test): ?>
    <div class="info" style="margin-top:15px;background:#e8f5e9;border-left:4px solid #2e7d32;">
      <b>✓ RECOMMENDED FOR TRADE TEST</b><br>
      Recommendation Date: <?= date('d F Y', strtotime($appendixH_trade_test['recommended_date'])) ?><br>
      Assessor: <?= htmlspecialchars($facilitator['firstName'].' '.$facilitator['lastName']) ?>
    </div>
  <?php endif; ?>

<?php else: ?>
  <p style="font-style:italic;color:#999;margin-top:15px;">No access recommendation recorded yet.</p>
<?php endif; ?>

<div class="sig-row" style="margin-top:30px;">
  <div class="sig-blk"><label>Assessor Signature:</label><div class="sig-line"><input type="text"></div></div>
  <div class="sig-blk"><label>Date:</label><div class="sig-line"><input type="date" value="<?= date('Y-m-d') ?>"></div></div>
</div>

</div>
```

## Implementation Steps

1. Backup current `mobile/arpl_toolkit_dynamic.php`
2. Add data loading queries (Steps 8-11) after learner data loading
3. Update contents page to include Appendix H
4. Update Appendix B section to show saved ratings from database
5. Update Appendix D section to show saved yes/no responses
6. Update Appendix E section to show saved ratings and comments
7. Add new Appendix H section at the end (before closing tags)
8. Test with learner ID 20286 who has saved data

## Testing Plan

Test URL: `http://192.168.0.57:8080/assessorReport2/mobile/arpl_toolkit_dynamic.php?learnerID=20286&classID=XXX`

### Verify:
1. ✓ Appendix B shows saved ratings (1-5) from `arplappxb_activity_ratings`
2. ✓ Appendix D shows saved yes/no from `arpl_appendix_d`  
3. ✓ Appendix E shows saved ratings + comments from `arplappxe_electrician_activity_ratings`
4. ✓ Appendix H displays as last tab
5. ✓ Appendix H shows 4 assessment items from `appxh_acrelectrician`
6. ✓ If recommendation exists, show saved status for each item
7. ✓ If gap closure, show assigned unit standards
8. ✓ If trade test ready, show recommendation notice
9. ✓ Print/PDF generation works correctly
10. ✓ All saved data displays with green "prefilled" styling

## Files to Modify

- `mobile/arpl_toolkit_dynamic.php` - Main file (1528 lines)

## Files Created

- `ARPL_TOOLKIT_UPDATE_PLAN.md` - This document

---

**Status**: Ready for implementation  
**Estimated Time**: 2-3 hours for full implementation and testing  
**Priority**: High - Matches mobile app structure
