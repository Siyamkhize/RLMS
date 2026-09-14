<?php
// arl: ARPL main hierarchical navigator page
/**
 * ARPL Assessment Hierarchical Navigator
 *
 * Full interactive hierarchy with drill-down:
 * 1️⃣ Learning Pathway (ARPL - Project 97)
 *  └─ 2️⃣ Trade (Electrician - OFO 671101)
 *      └─ 3️⃣ Paper (Electrical Theory Paper 1 - ID: 11)
 *          └─ 4️⃣ Questions (21 total)
 *              └─ 5️⃣ Learner Data (3 learners × 21 questions = 63 rows)
 */

require_once 'connection.php';

$section = isset($_GET['section']) ? $_GET['section'] : 'pathway';

?>
<!DOCTYPE html>
<html>
<head>
    <title>ARPL Assessment Hierarchy Navigator</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }

        .container { max-width: 1000px; margin: 0 auto; }

        h1 {
            color: white;
            text-align: center;
            margin-bottom: 30px;
            font-size: 2.2em;
            text-shadow: 0 2px 10px rgba(0,0,0,0.2);
        }

        .hierarchy {
            background: white;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            margin-bottom: 20px;
        }

        .hierarchy-level {
            border-left: 5px solid #667eea;
            padding: 20px;
            background: #f9f9f9;
            cursor: pointer;
            transition: all 0.3s ease;
            margin: 0;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .hierarchy-level:hover {
            background: #f0f0f0;
            border-left-color: #764ba2;
            transform: translateX(5px);
        }

        .hierarchy-level.active {
            background: #e3f2fd;
            border-left-color: #667eea;
        }

        .hierarchy-level h2 {
            margin: 0;
            font-size: 1.3em;
            color: #333;
        }

        .hierarchy-level p {
            margin: 8px 0 0 0;
            color: #666;
            font-size: 0.9em;
        }

        .hierarchy-badge {
            background: #667eea;
            color: white;
            padding: 8px 15px;
            border-radius: 20px;
            font-weight: 600;
            font-size: 0.9em;
        }

        .hierarchy-content {
            padding: 20px;
            display: none;
            border-top: 1px solid #ddd;
        }

        .hierarchy-content.expanded {
            display: block;
            animation: slideDown 0.3s ease;
        }

        @keyframes slideDown {
            from {
                opacity: 0;
                transform: translateY(-10px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }

        .info-card {
            background: #f5f5f5;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #667eea;
        }

        .info-label {
            font-size: 0.8em;
            color: #999;
            font-weight: 600;
            text-transform: uppercase;
        }

        .info-value {
            font-size: 1.2em;
            color: #333;
            font-weight: 600;
            margin-top: 5px;
        }

        .questions-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }

        .questions-table thead {
            background: #667eea;
            color: white;
        }

        .questions-table th {
            padding: 12px;
            text-align: left;
            font-weight: 600;
        }

        .questions-table td {
            padding: 12px;
            border-bottom: 1px solid #ddd;
        }

        .questions-table tbody tr:hover {
            background: #f5f5f5;
        }

        .learner-row {
            background: #e3f2fd !important;
            font-weight: 600;
            color: #1976d2;
        }

        .badge {
            display: inline-block;
            padding: 4px 10px;
            border-radius: 4px;
            font-size: 0.85em;
            font-weight: 600;
        }

        .badge-easy { background: #c8e6c9; color: #2e7d32; }
        .badge-medium { background: #fff9c4; color: #f57f17; }
        .badge-hard { background: #ffccbc; color: #d84315; }

        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }

        .stat {
            text-align: center;
            background: #f5f5f5;
            padding: 15px;
            border-radius: 8px;
        }

        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }

        .stat-label {
            font-size: 0.85em;
            color: #999;
            margin-top: 8px;
        }

        .breadcrumb {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 20px;
            color: white;
            font-size: 0.95em;
        }

        .breadcrumb span {
            opacity: 0.7;
        }

        .breadcrumb span.active {
            opacity: 1;
            font-weight: 600;
        }

        .arrow {
            opacity: 0.5;
            margin: 0 5px;
        }
    </style>
</head>
<body>

<div class="container">
    <h1>📚 ARPL Assessment Hierarchy Navigator</h1>

    <!-- Breadcrumb -->
    <div class="breadcrumb">
        <span class="<?php echo $section === 'pathway' ? 'active' : ''; ?>">1️⃣ Pathway</span>
        <span class="arrow">→</span>
        <span class="<?php echo $section === 'trade' ? 'active' : ''; ?>">2️⃣ Trade</span>
        <span class="arrow">→</span>
        <span class="<?php echo $section === 'paper' ? 'active' : ''; ?>">3️⃣ Paper</span>
        <span class="arrow">→</span>
        <span class="<?php echo $section === 'questions' ? 'active' : ''; ?>">4️⃣ Questions</span>
    </div>

    <!-- LEVEL 1: PATHWAY -->
    <div class="hierarchy">
        <div class="hierarchy-level <?php echo $section === 'pathway' ? 'active' : ''; ?>" onclick="location.href='?section=pathway'">
            <div>
                <h2>🎓 1️⃣ Learning Pathway</h2>
                <p>Accelerated Rapid Pathways Learning - Project ID: 97</p>
            </div>
            <div class="hierarchy-badge">ARPL</div>
        </div>
        <?php if ($section === 'pathway'): ?>
        <div class="hierarchy-content expanded">
            <div class="info-grid">
                <div class="info-card">
                    <div class="info-label">Pathway Name</div>
                    <div class="info-value">ARPL</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Full Name</div>
                    <div class="info-value">Accelerated Rapid Pathways Learning</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Project ID</div>
                    <div class="info-value">97</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Structure Type</div>
                    <div class="info-value">Trade-Based</div>
                </div>
            </div>
            <p style="color: #666; line-height: 1.6;">
                ARPL is a specialized framework designed for rapid skills development. Instead of traditional qualification-based pathways,
                ARPL organizes training around specific trades, allowing for faster implementation and competency-based progression.
            </p>
        </div>
        <?php endif; ?>
    </div>

    <!-- LEVEL 2: TRADE -->
    <div class="hierarchy">
        <div class="hierarchy-level <?php echo $section === 'trade' ? 'active' : ''; ?>" onclick="location.href='?section=trade'">
            <div>
                <h2>⚡ 2️⃣ Trade</h2>
                <p>Electrician - OFO Code: 671101</p>
            </div>
            <div class="hierarchy-badge">ELECTRICIAN</div>
        </div>
        <?php if ($section === 'trade'): ?>
        <div class="hierarchy-content expanded">
            <div class="info-grid">
                <div class="info-card">
                    <div class="info-label">Trade Name</div>
                    <div class="info-value">Electrician</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Trade ID</div>
                    <div class="info-value">1</div>
                </div>
                <div class="info-card">
                    <div class="info-label">OFO Code</div>
                    <div class="info-value">671101</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Framework</div>
                    <div class="info-value">NLQF Level 3</div>
                </div>
            </div>
            <p style="color: #666; line-height: 1.6;">
                The Electrician trade encompasses skills required for electrical installation, maintenance, and repair work.
                Covers theoretical knowledge, practical competencies, safety procedures, and industry-standard regulations.
            </p>
        </div>
        <?php endif; ?>
    </div>

    <!-- LEVEL 3: PAPER -->
    <div class="hierarchy">
        <div class="hierarchy-level <?php echo $section === 'paper' ? 'active' : ''; ?>" onclick="location.href='?section=paper'">
            <div>
                <h2>📄 3️⃣ Assessment Paper</h2>
                <p>Electrical Theory Paper 1 - Paper ID: 11</p>
            </div>
            <div class="hierarchy-badge">PAPER 11</div>
        </div>
        <?php if ($section === 'paper'): ?>
        <div class="hierarchy-content expanded">
            <div class="info-grid">
                <div class="info-card">
                    <div class="info-label">Paper Title</div>
                    <div class="info-value">Electrical Theory Paper 1</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Paper ID</div>
                    <div class="info-value">11</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Paper Type</div>
                    <div class="info-value">Theory</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Duration</div>
                    <div class="info-value">120 Minutes</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Total Marks</div>
                    <div class="info-value">100</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Pass Score</div>
                    <div class="info-value">60 (60%)</div>
                </div>
            </div>

            <div class="stats">
                <div class="stat">
                    <div class="stat-value">21</div>
                    <div class="stat-label">Questions</div>
                </div>
                <div class="stat">
                    <div class="stat-value">100</div>
                    <div class="stat-label">Total Marks</div>
                </div>
                <div class="stat">
                    <div class="stat-value">13</div>
                    <div class="stat-label">Easy</div>
                </div>
                <div class="stat">
                    <div class="stat-value">8</div>
                    <div class="stat-label">Medium</div>
                </div>
            </div>
        </div>
        <?php endif; ?>
    </div>

    <!-- LEVEL 4: QUESTIONS & LEARNER DATA -->
    <div class="hierarchy">
        <div class="hierarchy-level <?php echo $section === 'questions' ? 'active' : ''; ?>" onclick="location.href='?section=questions'">
            <div>
                <h2>❓ 4️⃣ Questions & Learner Data</h2>
                <p>21 Questions × 3 Learners = 63 Data Rows</p>
            </div>
            <div class="hierarchy-badge">63 ROWS</div>
        </div>
        <?php if ($section === 'questions'): ?>
        <div class="hierarchy-content expanded">
            <p style="color: #666; margin-bottom: 20px;">
                <strong>Combined view:</strong> All learner-question relationships from Class 782 with Paper 11 questions
            </p>

            <?php
            // Execute the corrected query
            $query = "
            SELECT
                ld.LearnerID,
                CONCAT(ld.Name, ' ', ld.Surname) as learner_name,
                ld.Email,
                ld.PhoneNumber,
                aq.question_number,
                aq.question_text,
                aq.marks,
                aq.difficulty_level,
                aq.correct_answer,
                ap.paper_title,
                ap.total_marks,
                ap.passing_score,
                ap.duration_minutes
            FROM learnerdetails ld
            CROSS JOIN arpl_questions aq
            CROSS JOIN arpl_papers ap
            WHERE ld.classID = 782
                AND ap.trade_ofo_code = '671101'
                AND ap.paper_type = 'theory'
                AND aq.paper_id = ap.id
            ORDER BY ld.LearnerID, aq.question_number
            ";

            $result = $conn->query($query);

            if (!$result) {
                echo "<div style='background: #ffebee; color: #c62828; padding: 15px; border-radius: 5px;'>";
                echo "❌ Query Error: " . $conn->error;
                echo "</div>";
            } else {
                $total_rows = $result->num_rows;

                echo "<div class='stats'>";
                echo "<div class='stat'>";
                echo "<div class='stat-value'>$total_rows</div>";
                echo "<div class='stat-label'>Total Rows</div>";
                echo "</div>";
                echo "<div class='stat'>";
                echo "<div class='stat-value'>3</div>";
                echo "<div class='stat-label'>Learners</div>";
                echo "</div>";
                echo "<div class='stat'>";
                echo "<div class='stat-value'>21</div>";
                echo "<div class='stat-label'>Questions</div>";
                echo "</div>";
                echo "</div>";

                // Display table
                echo "<table class='questions-table'>";
                echo "<thead><tr>";
                echo "<th>Learner</th>";
                echo "<th>Q#</th>";
                echo "<th>Question</th>";
                echo "<th>Marks</th>";
                echo "<th>Difficulty</th>";
                echo "</tr></thead><tbody>";

                $result = $conn->query($query);
                $current_learner = null;

                while ($row = $result->fetch_assoc()) {
                    if ($current_learner !== $row['LearnerID']) {
                        $current_learner = $row['LearnerID'];
                        echo "<tr class='learner-row'>";
                        echo "<td colspan='5'>👤 " . $row['learner_name'] . " (ID: " . $row['LearnerID'] . ") | Email: " . $row['Email'] . " | Phone: " . $row['PhoneNumber'] . "</td>";
                        echo "</tr>";
                    }

                    $difficulty_class = 'badge-' . strtolower($row['difficulty_level']);
                    echo "<tr>";
                    echo "<td></td>";
                    echo "<td><strong>Q" . $row['question_number'] . "</strong></td>";
                    echo "<td>" . substr($row['question_text'], 0, 60) . "...</td>";
                    echo "<td>{$row['marks']} marks</td>";
                    echo "<td><span class='badge $difficulty_class'>" . ucfirst($row['difficulty_level']) . "</span></td>";
                    echo "</tr>";
                }

                echo "</tbody></table>";
            }
            ?>
        </div>
        <?php endif; ?>
    </div>

    <div style="text-align: center; margin-top: 30px;">
        <p style="color: white; font-size: 0.9em;">
            ✓ Complete hierarchy navigation • Click each level to expand details
        </p>
    </div>
</div>

</body>
</html>

<?php $conn->close(); ?>
