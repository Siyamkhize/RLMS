<?php
require_once 'connection.php';
require_once 'vendor/autoload.php';

use setasign\Fpdi\Fpdi;

header('Content-Type: application/pdf');
header('Content-Disposition: inline; filename="moderation_feedback_report.pdf"');

try {
    if (!isset($_GET['class_id'])) {
        throw new Exception('Class ID is required');
    }

    $class_id = $_GET['class_id'];

    // Fetch class information
    $class_query = "SELECT className, classDescription FROM class WHERE classID = ?";
    $stmt = $conn->prepare($class_query);
    $stmt->bind_param("s", $class_id);
    $stmt->execute();
    $class_result = $stmt->get_result();
    $class_info = $class_result->fetch_assoc();

    if (!$class_info) {
        throw new Exception('Class not found');
    }

    // Fetch learners and their moderation data
    $learners_query = "SELECT DISTINCT
                        l.LearnerID,
                        l.Name,
                        l.Surname,
                        l.IDNumber
                      FROM learner l
                      WHERE l.classID = ?
                      ORDER BY l.Surname, l.Name";

    $stmt = $conn->prepare($learners_query);
    $stmt->bind_param("s", $class_id);
    $stmt->execute();
    $learners_result = $stmt->get_result();

    // Create PDF
    $pdf = new FPDF();
    $pdf->AddPage();
    $pdf->SetFont('Arial', 'B', 16);

    // Title
    $pdf->Cell(0, 10, 'Moderation Feedback Report', 0, 1, 'C');
    $pdf->Ln(5);

    // Class Information
    $pdf->SetFont('Arial', 'B', 12);
    $pdf->Cell(0, 8, 'Class: ' . $class_info['className'], 0, 1);
    $pdf->SetFont('Arial', '', 10);
    $pdf->Cell(0, 6, 'Description: ' . ($class_info['classDescription'] ?? 'N/A'), 0, 1);
    $pdf->Ln(5);

    // Process each learner
    while ($learner = $learners_result->fetch_assoc()) {
        $learner_id = $learner['LearnerID'];
        
        $pdf->SetFont('Arial', 'B', 11);
        $pdf->Cell(0, 8, 'Learner: ' . $learner['Name'] . ' ' . $learner['Surname'] . ' (ID: ' . $learner['IDNumber'] . ')', 0, 1);
        $pdf->SetFont('Arial', '', 9);

        // Fetch moderation data for this learner
        $moderation_query = "SELECT 
                                m.exercise_name,
                                m.marks_scored,
                                m.total_marks,
                                m.moderator_status,
                                m.moderator_comment,
                                m.assessment_type,
                                us.unit_standard_name
                            FROM marks m
                            LEFT JOIN unit_standards us ON m.unit_standard_id = us.unit_standard_id
                            WHERE m.learner_id = ? AND m.moderator_status IS NOT NULL
                            ORDER BY us.unit_standard_name, m.assessment_type, m.exercise_name";

        $mod_stmt = $conn->prepare($moderation_query);
        $mod_stmt->bind_param("s", $learner_id);
        $mod_stmt->execute();
        $mod_result = $mod_stmt->get_result();

        if ($mod_result->num_rows > 0) {
            $current_unit = '';
            while ($mod = $mod_result->fetch_assoc()) {
                // Unit Standard header
                if ($current_unit != $mod['unit_standard_name']) {
                    $current_unit = $mod['unit_standard_name'];
                    $pdf->SetFont('Arial', 'B', 10);
                    $pdf->Cell(0, 6, 'Unit Standard: ' . $current_unit, 0, 1);
                    $pdf->SetFont('Arial', '', 9);
                }

                // Exercise details
                $pdf->Cell(0, 5, '  ' . $mod['assessment_type'] . ' - ' . $mod['exercise_name'], 0, 1);
                $pdf->Cell(0, 5, '    Marks: ' . $mod['marks_scored'] . '/' . $mod['total_marks'], 0, 1);
                $pdf->Cell(0, 5, '    Status: ' . $mod['moderator_status'], 0, 1);
                
                if (!empty($mod['moderator_comment'])) {
                    $pdf->MultiCell(0, 5, '    Comment: ' . $mod['moderator_comment']);
                }
                $pdf->Ln(2);
            }
        } else {
            $pdf->Cell(0, 6, '  No moderation data available', 0, 1);
        }

        $pdf->Ln(5);
    }

    // Output PDF
    $pdf->Output('I', 'moderation_feedback_report.pdf');

} catch (Exception $e) {
    // If error, output JSON error instead
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>
