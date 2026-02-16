<?php
require_once 'connection.php';
require_once 'vendor/autoload.php';

use setasign\Fpdi\Fpdi;

header('Content-Type: application/pdf');
header('Content-Disposition: inline; filename="learner_moderation_report.pdf"');

try {
    if (!isset($_GET['learner_id'])) {
        throw new Exception('Learner ID is required');
    }

    $learner_id = $_GET['learner_id'];

    // Fetch learner information
    $learner_query = "SELECT 
                        l.LearnerID,
                        l.Name,
                        l.Surname,
                        l.IDNumber,
                        c.className,
                        c.classDescription
                      FROM learner l
                      LEFT JOIN class c ON l.classID = c.classID
                      WHERE l.LearnerID = ?";

    $stmt = $conn->prepare($learner_query);
    $stmt->bind_param("s", $learner_id);
    $stmt->execute();
    $learner_result = $stmt->get_result();
    $learner_info = $learner_result->fetch_assoc();

    if (!$learner_info) {
        throw new Exception('Learner not found');
    }

    // Create PDF
    $pdf = new FPDF();
    $pdf->AddPage();
    $pdf->SetFont('Arial', 'B', 16);

    // Title
    $pdf->Cell(0, 10, 'Learner Moderation Report', 0, 1, 'C');
    $pdf->Ln(5);

    // Learner Information
    $pdf->SetFont('Arial', 'B', 12);
    $pdf->Cell(0, 8, 'Learner Information', 0, 1);
    $pdf->SetFont('Arial', '', 10);
    $pdf->Cell(0, 6, 'Name: ' . $learner_info['Name'] . ' ' . $learner_info['Surname'], 0, 1);
    $pdf->Cell(0, 6, 'ID Number: ' . $learner_info['IDNumber'], 0, 1);
    $pdf->Cell(0, 6, 'Class: ' . ($learner_info['className'] ?? 'N/A'), 0, 1);
    $pdf->Ln(5);

    // Fetch all assessments with moderation
    $pdf->SetFont('Arial', 'B', 12);
    $pdf->Cell(0, 8, 'Moderation Details', 0, 1);
    $pdf->SetFont('Arial', '', 9);

    // Regular marks
    $marks_query = "SELECT 
                        m.exercise_name,
                        m.marks_scored,
                        m.total_marks,
                        m.moderator_status,
                        m.moderator_comment,
                        m.a_comment,
                        m.assessment_type,
                        m.assessment_date,
                        us.unit_standard_name,
                        us.unit_standard_id
                    FROM marks m
                    LEFT JOIN unit_standards us ON m.unit_standard_id = us.unit_standard_id
                    WHERE m.learner_id = ?
                    ORDER BY us.unit_standard_name, m.assessment_type, m.exercise_name";

    $stmt = $conn->prepare($marks_query);
    $stmt->bind_param("s", $learner_id);
    $stmt->execute();
    $marks_result = $stmt->get_result();

    $current_unit = '';
    $has_data = false;

    while ($mark = $marks_result->fetch_assoc()) {
        $has_data = true;
        
        // Unit Standard header
        if ($current_unit != $mark['unit_standard_name']) {
            $current_unit = $mark['unit_standard_name'];
            $pdf->SetFont('Arial', 'B', 11);
            $pdf->Cell(0, 7, 'Unit Standard: ' . $current_unit . ' (' . $mark['unit_standard_id'] . ')', 0, 1);
            $pdf->SetFont('Arial', '', 9);
        }

        // Assessment details
        $pdf->SetFont('Arial', 'B', 10);
        $pdf->Cell(0, 6, '  ' . $mark['assessment_type'] . ' - ' . $mark['exercise_name'], 0, 1);
        $pdf->SetFont('Arial', '', 9);
        
        $pdf->Cell(0, 5, '    Date: ' . ($mark['assessment_date'] ?? 'N/A'), 0, 1);
        $pdf->Cell(0, 5, '    Marks: ' . $mark['marks_scored'] . '/' . $mark['total_marks'], 0, 1);
        
        if (!empty($mark['moderator_status'])) {
            $pdf->Cell(0, 5, '    Moderator Status: ' . $mark['moderator_status'], 0, 1);
        }
        
        if (!empty($mark['a_comment'])) {
            $pdf->MultiCell(0, 5, '    Assessor Comment: ' . $mark['a_comment']);
        }
        
        if (!empty($mark['moderator_comment'])) {
            $pdf->MultiCell(0, 5, '    Moderator Comment: ' . $mark['moderator_comment']);
        }
        
        $pdf->Ln(3);
    }

    // Logbook marks
    $logbook_query = "SELECT 
                        lm.unit_standard_id,
                        lm.unit_standard_name,
                        lm.marks,
                        lm.moderator_status,
                        lm.moderator_comment,
                        lm.a_comment,
                        lm.assessment_date
                    FROM logbook_marks lm
                    WHERE lm.learner_id = ?
                    ORDER BY lm.unit_standard_name";

    $stmt = $conn->prepare($logbook_query);
    $stmt->bind_param("s", $learner_id);
    $stmt->execute();
    $logbook_result = $stmt->get_result();

    if ($logbook_result->num_rows > 0) {
        $pdf->SetFont('Arial', 'B', 11);
        $pdf->Cell(0, 7, 'Logbook Assessments', 0, 1);
        $pdf->SetFont('Arial', '', 9);

        while ($logbook = $logbook_result->fetch_assoc()) {
            $has_data = true;
            
            $pdf->SetFont('Arial', 'B', 10);
            $pdf->Cell(0, 6, '  ' . $logbook['unit_standard_name'] . ' (' . $logbook['unit_standard_id'] . ')', 0, 1);
            $pdf->SetFont('Arial', '', 9);
            
            $pdf->Cell(0, 5, '    Date: ' . ($logbook['assessment_date'] ?? 'N/A'), 0, 1);
            
            // Determine total marks based on unit standard
            $total_marks = ($logbook['unit_standard_id'] == '13958' || $logbook['unit_standard_id'] == '14555') ? 50 : 100;
            $pdf->Cell(0, 5, '    Marks: ' . $logbook['marks'] . '/' . $total_marks, 0, 1);
            
            if (!empty($logbook['moderator_status'])) {
                $pdf->Cell(0, 5, '    Moderator Status: ' . $logbook['moderator_status'], 0, 1);
            }
            
            if (!empty($logbook['a_comment'])) {
                $pdf->MultiCell(0, 5, '    Assessor Comment: ' . $logbook['a_comment']);
            }
            
            if (!empty($logbook['moderator_comment'])) {
                $pdf->MultiCell(0, 5, '    Moderator Comment: ' . $logbook['moderator_comment']);
            }
            
            $pdf->Ln(3);
        }
    }

    if (!$has_data) {
        $pdf->Cell(0, 6, 'No assessment data available for this learner.', 0, 1);
    }

    // Output PDF
    $pdf->Output('I', 'learner_moderation_report.pdf');

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
