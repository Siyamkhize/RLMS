# Appendix E Circle Format Implementation Plan

**Status**: Ready for Implementation  
**Scope**: Apply Flutter circle format to Appendix E (Practical Skills Assessment)  
**Date**: July 11, 2026

---

## Current State vs Desired State

### ❌ CURRENT (Broken)
```
Appendix E displays blank table:
┌──────────────────┬────────┬──────────┬──────────────────┐
│ Practical Skill  │ Rating │ Evidence │ Assessor Comments│
├──────────────────┼────────┼──────────┼──────────────────┤
│ Skill 1          │  ___   │    ☐     │ _______________  │
│ Skill 2          │  ___   │    ☐     │ _______________  │
│ ...              │  ___   │    ☐     │ _______________  │
└──────────────────┴────────┴──────────┴──────────────────┘

PROBLEMS:
- Does NOT load ratings from database
- Shows empty "___" for rating
- Does NOT display assessor comments
- Does NOT show assessment dates
- Only loads activities, not ratings data
```

### ✅ DESIRED (Like Appendix B)
```
Appendix E with Circle Format:
┌─────────────────────────────────────────────────────────┐
│ 1 │ Practical Activity Name                    ✓ RATED   │
│   │ Rating: ✓ ✓ ✓ ✓ ○ (4/5 - Proficient)              │
│   │ Notes: Assessment comments from assessor...        │
│   │ Assessed: 09 Jul 2026                               │
└─────────────────────────────────────────────────────────┘

IMPROVEMENTS:
- Loads ACTUAL ratings from database
- Shows circle format (✓ ○ ○ ○ ○)
- Displays assessor comments
- Shows assessment dates
- Card-based layout like Appendix B
```

---

## Root Cause Analysis

### Issue 1: Appendix E Query is Incomplete
**Location**: Line 268-276 in `/web/arpl_pdf.php`

**Current Code**:
```php
// ── LOAD APPENDIX E DATA (Practical Assessment) ────────────────
$appendixEActivities = [];
$eTable = "arplappxe_plumbing_activities"; // Based on trade
$st = $conn->query("SELECT * FROM $eTable ORDER BY activity_id ASC LIMIT 15");
if ($st) {
    while ($row = $st->fetch_assoc()) {
        $appendixEActivities[] = $row;
    }
}
```

**Problems**:
1. Hardcoded table name: `arplappxe_plumbing_activities` (should be trade-aware)
2. **NO LEFT JOIN** to get ratings data
3. Returns empty/NULL values for rating, comments, date
4. Should match Appendix B query pattern (which works correctly)

### Issue 2: Appendix E Rendering is Just a Table
**Location**: Line 910-940 in `/web/arpl_pdf.php`

**Current Code**:
```php
<table class="ft" style="font-size:9px;">
    <tr><th>Practical Activity</th><th>Rating</th><th>Evidence</th><th>Comments</th></tr>
    <?php foreach ($appendixEActivities as $activity): ?>
    <tr>
        <td><?php echo htmlspecialchars(...); ?></td>
        <td style="text-align:center;">___</td>  <!-- BLANK! -->
        <td style="text-align:center;">☐</td>
        <td><small>_______________________________</small></td>
    </tr>
    <?php endforeach; ?>
</table>
```

**Problems**:
1. Renders as table (not cards)
2. Shows hardcoded `___` for ratings (not from database)
3. No circle format
4. No comments displayed
5. No assessment dates

---

## Solution: Mirror Appendix B Pattern

### Step 1: Fix the Query (Line 268-276)

**Before**:
```php
$appendixEActivities = [];
$eTable = "arplappxe_plumbing_activities";
$st = $conn->query("SELECT * FROM $eTable ORDER BY activity_id ASC LIMIT 15");
if ($st) {
    while ($row = $st->fetch_assoc()) {
        $appendixEActivities[] = $row;
    }
}
```

**After**:
```php
$appendixEActivities = [];

// Same trade-specific tables as Appendix B
$tradeActivityTables = [
    '671101' => 'arplappxb_electrician_activities',
    '641201' => 'arplappxb_bricklaying_activities',
    '642601' => 'arplappxb_plumbing_activities',
];

$tradeRatingsTables = [
    '671101' => 'arplappxe_electrician_activity_ratings',
    '641201' => 'arplappxe_bricklaying_activity_ratings',
    '642601' => 'arplappxb_activity_ratings',
];

$appendixEActivityTable = $tradeActivityTables[$ofo_code] ?? 'arplappxb_plumbing_activities';
$appendixERatingsTable = $tradeRatingsTables[$ofo_code] ?? 'arplappxb_activity_ratings';

// QUERY WITH LEFT JOIN (like Appendix B)
$appendixESql = "SELECT 
    act.activity_id,
    act.activity_number,
    act.activity_name,
    COALESCE(rat.competency_scale_id, NULL) as rating,
    COALESCE(rat.comments, '') as assessor_comments,
    COALESCE(rat.rating_date, NULL) as rating_date
FROM $appendixEActivityTable act
LEFT JOIN $appendixERatingsTable rat ON (
    rat.activity_id = act.activity_id 
    AND rat.learnerID = ?
    AND rat.ofo_number = ?
)
ORDER BY act.activity_number ASC";

$st = $conn->prepare($appendixESql);
if ($st) {
    $st->bind_param("is", $learnerID, $ofo_code);
    $st->execute();
    $result = $st->get_result();
    while ($row = $result->fetch_assoc()) {
        $appendixEActivities[] = $row;
    }
    $st->close();
}
```

### Step 2: Update Rendering to Use Circle Format

**Replace**: Lines 910-940 in PDF

**New Code**: Copy Appendix B card rendering but with `$appendixEActivities`:

```php
<!-- PAGE 9: APPENDIX E - PRACTICAL SKILLS ASSESSMENT -->
<div class="page">
    <table class="dht">
        <tr><td><b>DHET</b></td><td style="text-align: right;">ARPL Portfolio - Appendix E</td></tr>
    </table>

    <div class="appendix-title">Appendix E: Practical Skills Assessment - <?php echo htmlspecialchars($tradeName); ?></div>
    
    <p style="font-size:10pt;margin:5px 0;">Competency ratings and assessor feedback for each practical activity.</p>

    <!-- Rating Scale Reference -->
    <div style="background:#f5f5f5;border:1px solid #ddd;padding:8px;margin-bottom:12px;border-radius:4px;font-size:9px;">
        <strong>Rating Scale:</strong>
        <span style="margin-left:10px;"><span style="display:inline-block;width:12px;height:12px;background:#e74c3c;border-radius:2px;margin-right:3px;vertical-align:middle;"></span>1-2=Below</span>
        <span style="margin-left:10px;"><span style="display:inline-block;width:12px;height:12px;background:#f39c12;border-radius:2px;margin-right:3px;vertical-align:middle;"></span>3=Competent</span>
        <span style="margin-left:10px;"><span style="display:inline-block;width:12px;height:12px;background:#27ae60;border-radius:2px;margin-right:3px;vertical-align:middle;"></span>4-5=Advanced</span>
    </div>

    <?php if (!empty($appendixEActivities)): ?>
    <!-- Activity Cards with Circle Format (like Appendix B) -->
    <?php 
    $ratedCount = 0;
    $unratedCount = 0;
    foreach ($appendixEActivities as $idx => $activity): 
        $hasRating = !empty($activity['rating']);
        if ($hasRating) $ratedCount++;
        else $unratedCount++;
        
        // Map rating to proficiency level name
        $proficiencyText = 'Not Assessed';
        if ($hasRating) {
            $rating = intval($activity['rating']);
            switch($rating) {
                case 1: $proficiencyText = 'Fundamental'; break;
                case 2: $proficiencyText = 'Novice'; break;
                case 3: $proficiencyText = 'Competent'; break;
                case 4: $proficiencyText = 'Proficient'; break;
                case 5: $proficiencyText = 'Expert'; break;
            }
        }
        
        // Status badge
        if ($hasRating) {
            $rating = intval($activity['rating']);
            if ($rating >= 4) {
                $statusBadge = '<span style="background:#27ae60;color:#fff;padding:3px 8px;border-radius:12px;font-size:8px;font-weight:bold;">✓ RATED</span>';
            } elseif ($rating == 3) {
                $statusBadge = '<span style="background:#f39c12;color:#fff;padding:3px 8px;border-radius:12px;font-size:8px;font-weight:bold;">✓ RATED</span>';
            } else {
                $statusBadge = '<span style="background:#e74c3c;color:#fff;padding:3px 8px;border-radius:12px;font-size:8px;font-weight:bold;">⚠ RATED</span>';
            }
        } else {
            $statusBadge = '<span style="background:#e8e8e8;color:#666;padding:3px 8px;border-radius:12px;font-size:8px;font-weight:bold;">NOT RATED</span>';
        }
        
        $cardBg = $hasRating ? '#ffffff' : '#f9f9f9';
        $borderColor = $hasRating ? '#e8f5e9' : '#f5f5f5';
    ?>
    <!-- Activity Card -->
    <div style="background:<?php echo $cardBg; ?>;border:1px solid <?php echo $borderColor; ?>;border-radius:6px;padding:10px;margin-bottom:8px;page-break-inside:avoid;">
        <div style="display:flex;align-items:flex-start;gap:10px;">
            <!-- Activity Number Badge -->
            <div style="background:#f5f5f5;border-radius:4px;padding:6px 8px;min-width:30px;text-align:center;font-weight:bold;font-size:10px;">
                <?php echo ($idx + 1); ?>
            </div>
            
            <!-- Activity Details (Middle) -->
            <div style="flex:1;">
                <!-- Activity Name -->
                <div style="font-weight:bold;font-size:10px;margin-bottom:4px;color:#333;">
                    <?php echo htmlspecialchars($activity['activity_name'] ?? 'Activity'); ?>
                </div>
                
                <!-- Rating (Flutter Circle Format) -->
                <div style="font-size:9px;margin-bottom:3px;color:#666;">
                    <strong>Rating:</strong> 
                    <?php 
                    $circleStr = '';
                    if ($hasRating) {
                        $rating = intval($activity['rating']);
                        for ($i = 1; $i <= 5; $i++) {
                            $symbol = ($i <= $rating) ? '✓' : '○';
                            $color = ($i <= $rating) ? '#006341' : '#ccc';
                            $circleStr .= "<span style='color:$color;font-size:13px;margin-right:4px;font-weight:bold;'>$symbol</span>";
                        }
                        $circleStr .= " <strong style='color:#006341;margin-left:8px;'>(" . intval($activity['rating']) . "/5 - " . htmlspecialchars($proficiencyText) . ")</strong>";
                    } else {
                        $circleStr = "<span style='color:#ccc;font-size:13px;'>○ ○ ○ ○ ○</span> <em style='color:#999;margin-left:8px;'>(Not Assessed)</em>";
                    }
                    echo $circleStr;
                    ?>
                </div>
                
                <!-- Assessor Comments -->
                <?php if ($hasRating && !empty($activity['assessor_comments']) && $activity['assessor_comments'] !== '0'): ?>
                <div style="font-size:8px;color:#555;margin-top:3px;padding:4px;background:#fafafa;border-left:2px solid #006341;padding-left:6px;">
                    <strong>Notes:</strong> <?php echo htmlspecialchars(substr($activity['assessor_comments'], 0, 80)); ?>
                </div>
                <?php endif; ?>
                
                <!-- Rating Date -->
                <?php if ($hasRating && !empty($activity['rating_date'])): ?>
                <div style="font-size:8px;color:#999;margin-top:3px;">
                    <strong>Assessed:</strong> <?php echo date('d M Y', strtotime($activity['rating_date'])); ?>
                </div>
                <?php endif; ?>
            </div>
            
            <!-- Status Badge (Right) -->
            <div style="min-width:80px;text-align:right;">
                <?php echo $statusBadge; ?>
            </div>
        </div>
    </div>
    <?php endforeach; ?>
    
    <!-- Assessment Summary -->
    <div style="margin-top:15px;padding:10px;background:#f0f8f5;border-left:4px solid #27ae60;">
        <p style="font-size:9px;margin:0 0 5px 0;"><b>Assessment Summary:</b></p>
        <?php 
        $totalActivities = count($appendixEActivities);
        $percentComplete = $totalActivities > 0 ? round(($ratedCount / $totalActivities) * 100) : 0;
        ?>
        <p style="font-size:8px;margin:2px 0;color:#333;">
            ✓ Assessed: <strong><?php echo $ratedCount; ?></strong> of <?php echo $totalActivities; ?> activities 
            (<strong><?php echo $percentComplete; ?>%</strong> complete)
            <?php if ($unratedCount > 0): ?>
                | Pending: <strong><?php echo $unratedCount; ?></strong> activities
            <?php endif; ?>
        </p>
    </div>
    <?php else: ?>
    <p><em>No practical skills assessment data available</em></p>
    <?php endif; ?>
</div>
```

---

## Implementation Checklist

### Changes Required

1. **Query Fix** (Line 268-276)
   - [ ] Replace hardcoded table with trade mapping
   - [ ] Add LEFT JOIN to ratings table
   - [ ] Use parameterized queries
   - [ ] Verify works with all 3 trades

2. **Rendering Fix** (Line 910-940)
   - [ ] Replace table format with card format
   - [ ] Implement circle format (✓ ○)
   - [ ] Add rating colors
   - [ ] Display assessor comments
   - [ ] Show assessment dates
   - [ ] Add summary section

3. **Testing**
   - [ ] Test with Electrician (671101)
   - [ ] Test with Bricklaying (641201)  
   - [ ] Test with Plumbing (642601)
   - [ ] Verify with rated learner (20286)
   - [ ] Verify with unrated learner (16389)
   - [ ] Check PDF renders correctly

---

## Expected Results After Fix

### For Learner 20286 (Electrician with 14 Ratings on Appendix B)
```
Appendix E should display:
- Same 14 activities with ratings
- 9 activities showing ○ ○ ○ ○ ○ (Not Assessed)
- Circle format matching Appendix B exactly
- Assessment summary showing "14 of 23 (61%) complete"
```

### For Learner 16389 (No Ratings)
```
Appendix E should display:
- All 22 activities showing ○ ○ ○ ○ ○
- Status "NOT RATED" for all
- Summary showing "0 of 22 (0%) complete"
```

---

## Key Points

✅ **Use same table mapping as Appendix B**  
✅ **Use parameterized queries (security)**  
✅ **Apply circle format exactly like Appendix B**  
✅ **Test with all trades**  
✅ **Verify ratings display (not blank)**  
✅ **Keep assessment comments and dates**

---

## Files to Modify

1. `/web/arpl_pdf.php`
   - Lines 268-276: Query fix
   - Lines 910-940: Rendering fix

2. No other files affected (same logic as Appendix B)

---

**Ready for Implementation**: Yes  
**Risk Level**: Low (copying proven Appendix B pattern)  
**Estimated Time**: 30 minutes
