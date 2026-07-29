<?php
/**
 * ARPL PORTFOLIO OF EVIDENCE CHECKLIST
 * Department: Higher Education and Training, Republic of South Africa
 * Doc Ref: ARPL PoE checklist | Version 1 of 2017 | Date revised 08 May 2017
 *
 * Linked to `learnerdetails` for auto-populated candidate info.
 *
 * ASSUMED schema (adjust the SELECTs below if yours differ):
 *   learnerdetails: LearnerID, FirstName, Surname, IDNumber, ClassID
 *   classes:        ClassID, ClassName, TradeID
 *   trades:         TradeID, TradeName
 *
 * Usage:
 *   arpl_poe_checklist.php                 -> shows learner search/select
 *   arpl_poe_checklist.php?learner_id=123   -> loads & pre-populates that learner
 */

// ---------------------------------------------------------------------
// DB CONFIG - update to match your RLMS environment
// ---------------------------------------------------------------------
$db_host = "localhost";
$db_user = "your_db_user";
$db_pass = "your_db_pass";
$db_name = "rlms";

$conn = mysqli_connect($db_host, $db_user, $db_pass, $db_name);
if (!$conn) {
    die("Database connection failed: " . mysqli_connect_error());
}

$saved   = false;
$error   = "";
$learner = null;

// ---------------------------------------------------------------------
// Load learner if learner_id supplied (via GET on page load, or POST on save)
// ---------------------------------------------------------------------
$learner_id = 0;
if (isset($_GET['learner_id'])) {
    $learner_id = (int) $_GET['learner_id'];
} elseif (isset($_POST['learner_id'])) {
    $learner_id = (int) $_POST['learner_id'];
}

if ($learner_id > 0) {
    $stmt = mysqli_prepare($conn, "SELECT ld.LearnerID, ld.FirstName, ld.Surname, ld.IDNumber,
                                           c.ClassName, t.TradeID, t.TradeName AS Trade
                                    FROM learnerdetails ld
                                    LEFT JOIN classes c ON ld.ClassID = c.ClassID
                                    LEFT JOIN trades t ON c.TradeID = t.TradeID
                                    WHERE ld.LearnerID = ?");
    mysqli_stmt_bind_param($stmt, "i", $learner_id);
    mysqli_stmt_execute($stmt);
    $result = mysqli_stmt_get_result($stmt);
    $learner = mysqli_fetch_assoc($result);
    mysqli_stmt_close($stmt);

    if (!$learner) {
        $error = "No learner found for LearnerID $learner_id.";
    }
}

// ---------------------------------------------------------------------
// Handle checklist save
// ---------------------------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] === 'POST' && $learner) {

    $comments = mysqli_real_escape_string($conn, $_POST['comments'] ?? '');

    $candidate_date = $_POST['candidate_date'] ?? null;
    $assessor_name  = mysqli_real_escape_string($conn, $_POST['assessor_name'] ?? '');
    $assessor_date  = $_POST['assessor_date'] ?? null;
    $moderator_name = mysqli_real_escape_string($conn, $_POST['moderator_name'] ?? '');
    $moderator_date = $_POST['moderator_date'] ?? null;
    $clerk_name     = mysqli_real_escape_string($conn, $_POST['clerk_name'] ?? '');
    $clerk_date     = $_POST['clerk_date'] ?? null;

    // empty date strings -> NULL for the DB
    foreach (['candidate_date', 'assessor_date', 'moderator_date', 'clerk_date'] as $d) {
        if (empty($$d)) { $$d = null; }
    }

    $items = array();
    for ($i = 1; $i <= 21; $i++) {
        $items[$i] = isset($_POST['item_' . $i]) ? 1 : 0;
    }
    $items_json = json_encode($items);

    $sql = "INSERT INTO arpl_poe_checklist
            (learner_id, items_json, comments,
             candidate_date, assessor_name, assessor_date,
             moderator_name, moderator_date, clerk_name, clerk_date, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())";

    $stmt = mysqli_prepare($conn, $sql);
    mysqli_stmt_bind_param(
        $stmt, "isssssssss",
        $learner_id, $items_json, $comments,
        $candidate_date, $assessor_name, $assessor_date,
        $moderator_name, $moderator_date, $clerk_name, $clerk_date
    );

    if (mysqli_stmt_execute($stmt)) {
        $saved = true;
    } else {
        $error = "Save failed: " . mysqli_error($conn);
    }
    mysqli_stmt_close($stmt);
}

// Checklist item descriptions (rows 1-21, exact wording from the form)
$checklist_items = array(
    1  => "Application form",
    2  => "Certified ID copy",
    3  => "Curriculum Vitae",
    4  => "Certified copies of qualifications (if any) and service letter/s from current and or previous employer/s as per the CV",
    5  => "Fees payment records",
    6  => "Self-Evaluation/Interview checklist",
    7  => "Gap closure reports",
    8  => "Theory Assessment scripts",
    9  => "Register of Theory Assessment sitting",
    10 => "Practical Assessment of trade tasks",
    11 => "Register of Practical Assessment sitting",
    12 => "Workplace Experience evaluation checklist and photograph/s",
    13 => "Register of Workplace Experience evaluation sitting",
    14 => "Details of Assessor including the copy of his/her Artisan certificate and Registration No.",
    15 => "Feedback form",
    16 => "Appeals form/s",
    17 => "Recommendation for trade testing",
    18 => "Statement of Results",
    19 => "Trade test serial number",
    20 => "Trade test results",
    21 => "NAMB moderation report (only when chosen for Trade Test and PoE moderation)",
);

// For the "no learner selected yet" screen: list learners for a quick picker
$learner_list = array();
if (!$learner) {
    $res = mysqli_query($conn, "SELECT ld.LearnerID, ld.FirstName, ld.Surname, t.TradeName AS Trade
                                 FROM learnerdetails ld
                                 LEFT JOIN classes c ON ld.ClassID = c.ClassID
                                 LEFT JOIN trades t ON c.TradeID = t.TradeID
                                 ORDER BY ld.Surname, ld.FirstName LIMIT 500");
    if ($res) {
        while ($row = mysqli_fetch_assoc($res)) {
            $learner_list[] = $row;
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>ARPL Portfolio of Evidence Checklist</title>
<style>
    body {
        font-family: Arial, Helvetica, sans-serif;
        font-size: 13px;
        color: #000;
        max-width: 900px;
        margin: 20px auto;
        padding: 0 15px;
    }
    .header {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        border-bottom: 2px solid #000;
        padding-bottom: 10px;
        margin-bottom: 15px;
    }
    .header .title {
        font-size: 18px;
        font-weight: bold;
        text-transform: uppercase;
    }
    .header .dept {
        text-align: right;
        font-size: 12px;
    }
    .header .dept .name {
        font-size: 15px;
        font-weight: bold;
    }
    .header .dept small {
        display: block;
        line-height: 1.3;
    }
    .candidate-info {
        display: flex;
        flex-wrap: wrap;
        gap: 10px 40px;
        margin-bottom: 15px;
    }
    .candidate-info label {
        font-weight: bold;
        margin-right: 5px;
    }
    .candidate-info input[type=text] {
        border: none;
        border-bottom: 1px solid #000;
        min-width: 220px;
        font-size: 13px;
        background: #f4f4f4;
    }
    table.checklist {
        width: 100%;
        border-collapse: collapse;
        margin-bottom: 10px;
    }
    table.checklist th, table.checklist td {
        border: 1px solid #000;
        padding: 5px 6px;
        vertical-align: top;
    }
    table.checklist th {
        background: #dfe3e8;
        text-align: left;
        font-size: 13px;
    }
    table.checklist td.no {
        width: 35px;
        text-align: center;
    }
    table.checklist td.yes {
        width: 60px;
        text-align: center;
    }
    table.checklist td.yes input[type=checkbox] {
        width: 18px;
        height: 18px;
    }
    .comments-row td {
        height: 90px;
    }
    .comments-label {
        font-weight: bold;
        margin-bottom: 4px;
        display: block;
    }
    .comments-row textarea {
        width: 100%;
        height: 80px;
        border: none;
        resize: none;
        font-family: inherit;
        font-size: 13px;
    }
    .note {
        font-weight: bold;
        margin: 15px 0 10px;
    }
    .sign-block {
        margin-bottom: 8px;
        display: flex;
        align-items: center;
        gap: 10px;
        flex-wrap: wrap;
    }
    .sign-block label {
        font-weight: bold;
        min-width: 190px;
    }
    .sign-block input[type=text] {
        border: none;
        border-bottom: 1px solid #000;
        flex: 1;
        min-width: 150px;
        font-size: 13px;
    }
    .sign-block .date-label {
        font-weight: bold;
        min-width: 40px;
    }
    .sign-block input[type=date] {
        border: none;
        border-bottom: 1px solid #000;
        font-size: 13px;
    }
    table.footer {
        width: 100%;
        border-collapse: collapse;
        margin-top: 20px;
        font-size: 12px;
    }
    table.footer caption {
        text-align: center;
        font-weight: bold;
        padding-bottom: 4px;
    }
    table.footer td, table.footer th {
        border: 1px solid #000;
        padding: 4px 6px;
    }
    table.footer th {
        background: #dfe3e8;
        text-align: left;
        width: 15%;
    }
    .submit-row {
        margin-top: 20px;
        text-align: center;
    }
    .submit-row button {
        padding: 8px 30px;
        font-size: 14px;
        font-weight: bold;
        cursor: pointer;
    }
    .alert {
        padding: 10px;
        margin-bottom: 15px;
        border-radius: 4px;
    }
    .alert-success { background: #d4edda; border: 1px solid #28a745; color: #155724; }
    .alert-error   { background: #f8d7da; border: 1px solid #dc3545; color: #721c24; }

    .picker { margin-bottom: 20px; }
    .picker select { padding: 6px; font-size: 13px; min-width: 320px; }
    .picker button { padding: 6px 16px; font-size: 13px; margin-left: 8px; }

    @media print {
        .submit-row, .picker { display: none; }
        body { margin: 0; }
    }
</style>
</head>
<body>

<div class="header">
    <div class="title">ARPL Portfolio of Evidence Checklist</div>
    <div class="dept">
        <div class="name">higher education<br>&amp; training</div>
        <small>
            Department:<br>
            Higher Education and Training<br>
            <strong>REPUBLIC OF SOUTH AFRICA</strong>
        </small>
    </div>
</div>

<?php if ($error): ?>
    <div class="alert alert-error"><?php echo htmlspecialchars($error); ?></div>
<?php endif; ?>

<?php if ($saved): ?>
    <div class="alert alert-success">Checklist saved successfully for <?php echo htmlspecialchars($learner['FirstName'] . ' ' . $learner['Surname']); ?>.</div>
<?php endif; ?>

<?php if (!$learner): ?>

    <!-- ============== LEARNER PICKER ============== -->
    <form method="GET" action="" class="picker">
        <label for="learner_id"><strong>Select Learner:</strong></label><br><br>
        <select name="learner_id" id="learner_id" required>
            <option value="">-- Select a learner --</option>
            <?php foreach ($learner_list as $l): ?>
                <option value="<?php echo (int) $l['LearnerID']; ?>">
                    <?php echo htmlspecialchars($l['Surname'] . ', ' . $l['FirstName'] . ' (' . $l['Trade'] . ')'); ?>
                </option>
            <?php endforeach; ?>
        </select>
        <button type="submit">Load Checklist</button>
    </form>

<?php else: ?>

    <!-- ============== CHECKLIST FORM (learner loaded) ============== -->
    <form method="POST" action="">
        <input type="hidden" name="learner_id" value="<?php echo (int) $learner['LearnerID']; ?>">

        <div class="candidate-info">
            <div><label>Candidate Name/s:</label>
                <input type="text" value="<?php echo htmlspecialchars($learner['FirstName']); ?>" readonly></div>
            <div><label>Candidates Surname:</label>
                <input type="text" value="<?php echo htmlspecialchars($learner['Surname']); ?>" readonly></div>
            <div><label>ID Number:</label>
                <input type="text" value="<?php echo htmlspecialchars($learner['IDNumber']); ?>" readonly></div>
            <div><label>Trade:</label>
                <input type="text" value="<?php echo htmlspecialchars($learner['Trade']); ?>" readonly></div>
        </div>

        <table class="checklist">
            <thead>
                <tr>
                    <th class="no">No</th>
                    <th>Description</th>
                    <th class="yes">YES</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($checklist_items as $no => $desc): ?>
                <tr>
                    <td class="no"><?php echo $no; ?></td>
                    <td><?php echo htmlspecialchars($desc); ?></td>
                    <td class="yes">
                        <input type="checkbox" name="item_<?php echo $no; ?>" value="1">
                    </td>
                </tr>
                <?php endforeach; ?>
                <tr class="comments-row">
                    <td colspan="3">
                        <span class="comments-label">Comment/s:</span>
                        <textarea name="comments"></textarea>
                    </td>
                </tr>
            </tbody>
        </table>

        <div class="note">COMPLETE WHEN PoE CONTAINS ALL INFORMATION AS REQUIRED BEFORE MODERATION (1-19)</div>

        <div class="sign-block">
            <label>ARPL Candidate Signature:</label>
            <input type="text" name="candidate_sig">
            <span class="date-label">Date:</span>
            <input type="date" name="candidate_date">
        </div>

        <div class="sign-block">
            <label for="assessor_name">ARPL Assessor Name:</label>
            <input type="text" id="assessor_name" name="assessor_name">
            <span class="date-label">Signature:</span>
            <input type="text" name="assessor_sig" style="flex:1;">
            <span class="date-label">Date:</span>
            <input type="date" name="assessor_date">
        </div>

        <div class="sign-block">
            <label for="moderator_name">Moderator Name:</label>
            <input type="text" id="moderator_name" name="moderator_name">
            <span class="date-label">Signature:</span>
            <input type="text" name="moderator_sig" style="flex:1;">
            <span class="date-label">Date:</span>
            <input type="date" name="moderator_date">
        </div>

        <div class="sign-block">
            <label for="clerk_name">Name of Administration Clerk:</label>
            <input type="text" id="clerk_name" name="clerk_name">
            <span class="date-label">Signature:</span>
            <input type="text" name="clerk_sig" style="flex:1;">
            <span class="date-label">Date:</span>
            <input type="date" name="clerk_date">
        </div>

        <table class="footer">
            <caption>ARPL Portfolio of Evidence checklist.</caption>
            <tr>
                <th>Version</th>
                <td>1 of 2017</td>
                <th>Doc Ref.</th>
                <td>ARPL PoE checklist</td>
                <th>Doc. No.</th>
                <td></td>
            </tr>
            <tr>
                <th>Signature:</th>
                <td></td>
                <th>Page</th>
                <td>1 of 1</td>
                <th>Date revised</th>
                <td>08 May 2017</td>
            </tr>
        </table>

        <div class="submit-row">
            <button type="submit">Save Checklist</button>
            <button type="button" onclick="window.location='<?php echo strtok($_SERVER['PHP_SELF'], '?'); ?>'">Change Learner</button>
        </div>

    </form>

<?php endif; ?>

</body>
</html>
<?php mysqli_close($conn); ?>
