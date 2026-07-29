<?php
/**
 * ARPL GAP ANALYSIS REPORT  (MTL Training & Projects)
 *
 * Trade-aware: the Task/Assessment Method rows are NOT hardcoded here.
 * They are pulled from the `gap_analysis_report` table, filtered by the
 * selected learner's trade (Bricklaying / Electrician / Plumbing), which
 * is resolved the same way as the PoE checklist:
 *   learnerdetails.ClassID -> classes.ClassID -> classes.TradeID -> trades.TradeID
 *
 * Ratings + assessor info are saved into gap_analysis_submissions /
 * gap_analysis_submission_items (see CREATE TABLE statements at the
 * bottom of this file).
 *
 * Usage:
 *   arpl_gap_analysis.php                  -> learner picker
 *   arpl_gap_analysis.php?learner_id=123   -> loads that learner + their trade's tasks
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
$tasks   = array();

// ---------------------------------------------------------------------
// Resolve learner_id (GET on load, POST on save)
// ---------------------------------------------------------------------
$learner_id = 0;
if (isset($_GET['learner_id'])) {
    $learner_id = (int) $_GET['learner_id'];
} elseif (isset($_POST['learner_id'])) {
    $learner_id = (int) $_POST['learner_id'];
}

if ($learner_id > 0) {
    // Pull candidate info + their trade in one go
    $stmt = mysqli_prepare($conn, "SELECT ld.LearnerID, ld.FirstName, ld.Surname, ld.IDNumber,
                                           t.TradeID, t.TradeName AS Trade
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
    } elseif (empty($learner['TradeID'])) {
        $error = "Could not determine this learner's trade (check ClassID / classes.TradeID linkage).";
        $learner = null;
    } else {
        // Pull the trade-specific task list from gap_analysis_report
        $stmt2 = mysqli_prepare($conn, "SELECT TaskID, TaskNo, TaskName, AssessmentMethod
                                         FROM gap_analysis_report
                                         WHERE TradeID = ?
                                         ORDER BY TaskNo ASC");
        mysqli_stmt_bind_param($stmt2, "i", $learner['TradeID']);
        mysqli_stmt_execute($stmt2);
        $res2 = mysqli_stmt_get_result($stmt2);
        while ($row = mysqli_fetch_assoc($res2)) {
            $tasks[] = $row;
        }
        mysqli_stmt_close($stmt2);

        if (empty($tasks)) {
            $error = "No tasks found in gap_analysis_report for trade: " . htmlspecialchars($learner['Trade']) . ".";
        }
    }
}

// ---------------------------------------------------------------------
// Handle save
// ---------------------------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] === 'POST' && $learner && !empty($tasks)) {

    $assessor_name = mysqli_real_escape_string($conn, $_POST['assessor_name'] ?? '');
    $assessor_no   = mysqli_real_escape_string($conn, $_POST['assessor_no'] ?? '');
    $comments      = mysqli_real_escape_string($conn, $_POST['comments'] ?? '');
    $assess_date   = $_POST['assess_date'] ?? null;
    if (empty($assess_date)) { $assess_date = null; }

    mysqli_begin_transaction($conn);
    try {
        $stmt = mysqli_prepare($conn, "INSERT INTO gap_analysis_submissions
                (learner_id, trade_id, assessor_name, assessor_no, comments, assess_date, created_at)
                VALUES (?, ?, ?, ?, ?, ?, NOW())");
        mysqli_stmt_bind_param(
            $stmt, "iissss",
            $learner_id, $learner['TradeID'], $assessor_name, $assessor_no, $comments, $assess_date
        );
        mysqli_stmt_execute($stmt);
        $submission_id = mysqli_insert_id($conn);
        mysqli_stmt_close($stmt);

        $item_stmt = mysqli_prepare($conn, "INSERT INTO gap_analysis_submission_items
                (submission_id, task_id, rating) VALUES (?, ?, ?)");

        foreach ($tasks as $task) {
            $task_id = $task['TaskID'];
            $rating  = $_POST['rating_' . $task_id] ?? null; // 'Bad' | 'Fair' | 'Good'
            if (!in_array($rating, array('Bad', 'Fair', 'Good'), true)) {
                $rating = null;
            }
            mysqli_stmt_bind_param($item_stmt, "iis", $submission_id, $task_id, $rating);
            mysqli_stmt_execute($item_stmt);
        }
        mysqli_stmt_close($item_stmt);

        mysqli_commit($conn);
        $saved = true;
    } catch (Exception $e) {
        mysqli_rollback($conn);
        $error = "Save failed: " . $e->getMessage();
    }
}

// Learner picker list (when no learner selected yet)
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
<title>ARPL Gap Analysis Report</title>
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
        text-align: center;
        margin-bottom: 15px;
    }
    .header .logo {
        font-size: 22px;
        font-weight: bold;
        letter-spacing: 2px;
    }
    .header .logo small {
        display: block;
        font-size: 11px;
        font-weight: normal;
        letter-spacing: 4px;
        color: #555;
    }
    .header .title {
        margin-top: 12px;
        font-size: 16px;
        font-weight: bold;
        text-transform: uppercase;
    }
    table.info {
        width: 100%;
        border-collapse: collapse;
        margin-bottom: 20px;
    }
    table.info td {
        border: 1px solid #000;
        padding: 6px 8px;
    }
    table.info td.label {
        width: 25%;
        font-weight: bold;
        background: #f2f2f2;
    }
    table.info td.value input[type=text] {
        border: none;
        width: 100%;
        font-size: 13px;
        background: transparent;
    }
    table.tasks {
        width: 100%;
        border-collapse: collapse;
        margin-bottom: 20px;
    }
    table.tasks th, table.tasks td {
        border: 1px solid #000;
        padding: 6px 8px;
        vertical-align: middle;
        text-align: center;
    }
    table.tasks th {
        background: #dfe3e8;
    }
    table.tasks td.no { width: 35px; }
    table.tasks td.task { text-align: left; }
    table.tasks td.method { width: 130px; text-align: left; }
    table.tasks td.method select {
        width: 100%;
        font-size: 12px;
    }
    table.tasks td.rating { width: 55px; }
    table.tasks td.rating input[type=radio] {
        width: 16px;
        height: 16px;
    }
    .comments-label {
        font-weight: bold;
        display: block;
        margin: 15px 0 6px;
    }
    table.comments {
        width: 100%;
        border-collapse: collapse;
        margin-bottom: 15px;
    }
    table.comments td {
        border: 1px solid #000;
        height: 30px;
        padding: 6px 8px;
    }
    .date-row {
        margin-bottom: 20px;
    }
    .date-row label {
        font-weight: bold;
        margin-right: 8px;
    }
    .date-row input[type=date] {
        border: none;
        border-bottom: 1px solid #000;
        font-size: 13px;
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
        margin: 0 5px;
    }
    .alert {
        padding: 10px;
        margin-bottom: 15px;
        border-radius: 4px;
    }
    .alert-success { background: #d4edda; border: 1px solid #28a745; color: #155724; }
    .alert-error   { background: #f8d7da; border: 1px solid #dc3545; color: #721c24; }

    .picker { margin-bottom: 20px; text-align: center; }
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
    <div class="logo">MTL<br><small>TRAINING &amp; PROJECTS</small></div>
    <div class="title">
        ARPL Gap Analysis Report<?php echo $learner ? ' - ' . htmlspecialchars(strtoupper($learner['Trade'])) : ''; ?>
    </div>
</div>

<?php if ($error): ?>
    <div class="alert alert-error"><?php echo htmlspecialchars($error); ?></div>
<?php endif; ?>

<?php if ($saved): ?>
    <div class="alert alert-success">Gap analysis report saved for <?php echo htmlspecialchars($learner['FirstName'] . ' ' . $learner['Surname']); ?>.</div>
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
        <button type="submit">Load Gap Analysis</button>
    </form>

<?php else: ?>

    <form method="POST" action="">
        <input type="hidden" name="learner_id" value="<?php echo (int) $learner['LearnerID']; ?>">

        <table class="info">
            <tr>
                <td class="label">Candidate Name</td>
                <td class="value"><input type="text" value="<?php echo htmlspecialchars($learner['FirstName'] . ' ' . $learner['Surname']); ?>" readonly></td>
            </tr>
            <tr>
                <td class="label">ID No.</td>
                <td class="value"><input type="text" value="<?php echo htmlspecialchars($learner['IDNumber']); ?>" readonly></td>
            </tr>
            <tr>
                <td class="label">Assessor Name</td>
                <td class="value"><input type="text" name="assessor_name" placeholder="Enter assessor name"></td>
            </tr>
            <tr>
                <td class="label">Assessor No.</td>
                <td class="value"><input type="text" name="assessor_no" placeholder="Enter assessor number"></td>
            </tr>
        </table>

        <?php if (!empty($tasks)): ?>
        <table class="tasks">
            <thead>
                <tr>
                    <th>No.</th>
                    <th>Task</th>
                    <th>Assessment Method</th>
                    <th>Bad</th>
                    <th>Fair</th>
                    <th>Good</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($tasks as $t): ?>
                <tr>
                    <td class="no"><?php echo (int) $t['TaskNo']; ?></td>
                    <td class="task"><?php echo htmlspecialchars($t['TaskName']); ?></td>
                    <td class="method">
                        <select name="method_<?php echo (int) $t['TaskID']; ?>">
                            <?php foreach (array('Interview', 'Practical', 'Written', 'Observation') as $m): ?>
                                <option value="<?php echo $m; ?>" <?php echo (strcasecmp($t['AssessmentMethod'], $m) === 0) ? 'selected' : ''; ?>><?php echo $m; ?></option>
                            <?php endforeach; ?>
                        </select>
                    </td>
                    <td class="rating"><input type="radio" name="rating_<?php echo (int) $t['TaskID']; ?>" value="Bad"></td>
                    <td class="rating"><input type="radio" name="rating_<?php echo (int) $t['TaskID']; ?>" value="Fair"></td>
                    <td class="rating"><input type="radio" name="rating_<?php echo (int) $t['TaskID']; ?>" value="Good"></td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
        <?php endif; ?>

        <span class="comments-label">Assessor comments:</span>
        <table class="comments">
            <tr><td><textarea name="comments" style="width:100%; border:none; font-family:inherit; font-size:13px;" rows="3"></textarea></td></tr>
        </table>

        <div class="date-row">
            <label for="assess_date">Date:</label>
            <input type="date" id="assess_date" name="assess_date">
        </div>

        <div class="submit-row">
            <button type="submit">Save Gap Analysis</button>
            <button type="button" onclick="window.location='<?php echo strtok($_SERVER['PHP_SELF'], '?'); ?>'">Change Learner</button>
        </div>
    </form>

<?php endif; ?>

</body>
</html>
<?php mysqli_close($conn); ?>
