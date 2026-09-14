<?php
/**
 * ARPL APPENDIX E: Save Electrician Activity Ratings
 * Endpoint: POST /mobile/save_arpl_appendix_e_ratings.php
 *
 * Saves 1-5 competency ratings for electrician activities
 *
 * Request body (JSON):
 * {
 *   "learnerID": 11515,
 *   "facilitator_id": 1,
 *   "ofo_number": "671101",
 *   "ratings": {
 *     "1": { "activity_id": 1, "activity_name": "Activity Name", "rating": 4, "comments": "" },
 *     "2": { "activity_id": 2, "activity_name": "Activity Name", "rating": 5, "comments": "Good" },
 *     ...
 *   }
 * }
 */

header('Content-Type: application/json');

class InvalidInputException extends Exception {}
class DatabaseException extends Exception {}
class ValidationException extends Exception {}

try {
    // Get request body - support both POST JSON and GET/POST parameters
    $input = json_decode(file_get_contents('php://input'), true);

    // If no JSON input, check for GET or POST parameters
    if (!$input) {
        $input = array_merge($_GET, $_POST);

        // If ratings is a JSON string, decode it
        if (isset($input['ratings']) && is_string($input['ratings'])) {
            $input['ratings'] = json_decode($input['ratings'], true);
        }
    }

    if (empty($input)) {
        throw new InvalidInputException('Invalid JSON input or parameters');
    }

    $required = ['learnerID', 'facilitator_id', 'ofo_number', 'ratings'];
    foreach ($required as $field) {
        if (!isset($input[$field])) {
            throw new InvalidInputException("Missing required field: $field");
        }
    }

    $learnerID = intval($input['learnerID']);
    $facilitator_id = intval($input['facilitator_id']);
    $ofo_number = $input['ofo_number'];
    $ratings = $input['ratings'];

    require_once 'connection.php';

    if (!$conn) {
        throw new DatabaseException('Database connection failed');
    }

    $saved_count = 0;
    $errors = [];

    foreach ($ratings as $key => $ratingData) {
        try {
            $activity_id = intval($ratingData['activity_id']);
            $activity_name = $ratingData['activity_name'] ?? '';
            $rating = intval($ratingData['rating']);
            $comments = $ratingData['comments'] ?? '';
            $competency_scale_id = intval($ratingData['competency_scale_id'] ?? 0);
            $rating_date = $ratingData['rating_date'] ?? date('Y-m-d H:i:s');

            // Validate rating
            if ($rating < 1 || $rating > 5) {
                throw new ValidationException("Invalid rating for activity $activity_id");
            }

            // Check if rating exists
            $stmt = $conn->prepare("
                SELECT activity_rating_id FROM arplappxe_electrician_activity_ratings
                WHERE learnerID = ? AND facilitator_id = ? AND ofo_number = ? AND activity_id = ?
            ");
            $stmt->bind_param('iisi', $learnerID, $facilitator_id, $ofo_number, $activity_id);
            $stmt->execute();
            $result = $stmt->get_result();
            $existing = $result->fetch_assoc();
            $stmt->close();

            if ($existing) {
                // UPDATE
                $stmt = $conn->prepare("
                    UPDATE arplappxe_electrician_activity_ratings
                    SET competency_scale_id = ?, comments = ?, rating_date = ?
                    WHERE learnerID = ? AND facilitator_id = ? AND ofo_number = ? AND activity_id = ?
                ");
                $stmt->bind_param('issiisi', $competency_scale_id, $comments, $rating_date, $learnerID, $facilitator_id, $ofo_number, $activity_id);
            } else {
                // INSERT
                $stmt = $conn->prepare("
                    INSERT INTO arplappxe_electrician_activity_ratings
                    (learnerID, facilitator_id, ofo_number, activity_id, activity_name, competency_scale_id, comments, rating_date)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ");
                $stmt->bind_param('iisisis', $learnerID, $facilitator_id, $ofo_number, $activity_id, $activity_name, $competency_scale_id, $comments, $rating_date);
            }

            if (!$stmt->execute()) {
                throw new DatabaseException('Execute failed: ' . $stmt->error);
            }

            $saved_count++;
            $stmt->close();

        } catch (Exception $e) {
            $errors[] = "Activity $key error: " . $e->getMessage();
        }
    }

    echo json_encode([
        'status' => 'success',
        'message' => "Saved $saved_count ratings successfully",
        'data' => [
            'learnerID' => $learnerID,
            'facilitator_id' => $facilitator_id,
            'ofo_number' => $ofo_number,
            'saved_count' => $saved_count,
            'errors' => $errors
        ]
    ]);

    $conn->close();

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
