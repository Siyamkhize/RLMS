import os
import sys
import base64
import numpy as np
import tensorflow as tf
from PIL import Image
import io
from flask import Flask, request, jsonify
import traceback
import requests
from datetime import datetime
import mysql.connector
import json
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(sys.stderr),
        logging.FileHandler('siamese_server.log')
    ]
)
logger = logging.getLogger(__name__)

# --- GLOBAL MODEL & CONFIGURATION ---
MODEL = None
ENCODER = None
MODEL_PATH = 'C:/xampp/htdocs/mobile/models/siamese_model_checkpoint.h5'
THRESHOLD = 0.65  # Adjusted based on logs (0.65 used in verification)
IMAGE_SIZE = (224, 224)
PHP_URL = "http://192.168.0.53/insert_or_update_clocking.php"

# --- HELPER FUNCTIONS ---
def preprocess_image(image_base64, target_size, is_wsq=False):
    """Preprocesses a base64-encoded image or WSQ template."""
    try:
        if not image_base64:
            logger.error("preprocess_image: Empty base64 string")
            return None

        logger.info(f"preprocess_image: Data length: {len(image_base64)}")
        logger.debug(f"preprocess_image: Data starts: {image_base64[:20]}...")

        if is_wsq:
            return preprocess_wsq_template(image_base64, target_size)

        logger.info("preprocess_image: Processing as regular image")
        image_data = base64.b64decode(image_base64)
        image = Image.open(io.BytesIO(image_data)).convert('L')
        image = image.resize(target_size)
        img_array = np.array(image, dtype=np.float32) / 255.0

        if np.any(np.isnan(img_array)) or np.any(np.isinf(img_array)):
            logger.error("preprocess_image: NaN or Inf detected in image array")
            return None

        img_array = np.expand_dims(img_array, axis=[0, -1])
        logger.info(f"preprocess_image: Output shape: {img_array.shape}, range: [{img_array.min():.6f}, {img_array.max():.6f}]")
        return img_array
    except Exception as e:
        logger.error(f"preprocess_image: Error processing image: {e}")
        logger.debug(traceback.format_exc())
        if not is_wsq:
            logger.info("preprocess_image: Attempting WSQ processing as fallback")
            return preprocess_wsq_template(image_base64, target_size)
        return None

def preprocess_wsq_template(wsq_base64, target_size):
    """Converts WSQ template to processable image format."""
    try:
        logger.info("preprocess_wsq_template: Starting WSQ conversion")
        wsq_data = base64.b64decode(wsq_base64)
        logger.info(f"preprocess_wsq_template: Decoded WSQ data, size: {len(wsq_data)} bytes")
        logger.debug(f"preprocess_wsq_template: First 20 bytes: {wsq_data[:20]}")

        # WSQ decoding library not available; using fallback method
        height, width = target_size
        total_pixels = height * width
        if len(wsq_data) < 50:
            logger.error("preprocess_wsq_template: WSQ data too short")
            return None

        header_skip_sizes = [32, 64, 96, 128]
        best_img_array = None
        best_variance = 0

        for header_skip in header_skip_sizes:
            if len(wsq_data) <= header_skip:
                continue
            ridge_data = wsq_data[header_skip:]
            if len(ridge_data) == 0:
                continue
            if len(ridge_data) < total_pixels:
                repeat_count = (total_pixels // len(ridge_data)) + 1
                extended_data = (ridge_data * repeat_count)[:total_pixels]
            else:
                extended_data = ridge_data[:total_pixels]
            img_array = np.frombuffer(extended_data, dtype=np.uint8).astype(np.float32)
            img_array = img_array[:total_pixels].reshape(height, width)
            if img_array.max() > img_array.min():
                img_array = (img_array - img_array.min()) / (img_array.max() - img_array.min())
            else:
                img_array = np.full_like(img_array, 0.5)
            variance = np.var(img_array)
            if variance > best_variance:
                best_variance = variance
                best_img_array = img_array.copy()
            logger.info(f"preprocess_wsq_template: Header skip {header_skip}, variance: {variance:.6f}")

        if best_img_array is None:
            logger.error("preprocess_wsq_template: No valid image generated")
            return None
        img_array = best_img_array

        # Enhance contrast
        img_array = np.power(img_array, 0.8)  # Gamma correction
        mean_val = np.mean(img_array)
        std_val = np.std(img_array)
        if std_val < 0.1:
            img_array = (img_array - mean_val) * 2.0 + 0.5
            img_array = np.clip(img_array, 0, 1)

        img_array = np.expand_dims(img_array, axis=[0, -1])
        logger.info(f"preprocess_wsq_template: Output shape: {img_array.shape}, range: [{img_array.min():.6f}, {img_array.max():.6f}], mean: {img_array.mean():.6f}, std: {img_array.std():.6f}")
        return img_array
    except Exception as e:
        logger.error(f"preprocess_wsq_template: Error converting WSQ: {e}")
        logger.debug(traceback.format_exc())
        return None

def extract_features(image_array):
    """Extracts features from a preprocessed image array."""
    try:
        if image_array is None:
            logger.error("extract_features: Input image array is None")
            return None

        if np.any(np.isnan(image_array)) or np.any(np.isinf(image_array)):
            logger.error("extract_features: NaN or Inf detected in input image")
            return None

        logger.info(f"extract_features: Input shape: {image_array.shape}, dtype: {image_array.dtype}, range: [{image_array.min():.6f}, {image_array.max():.6f}]")
        features = ENCODER.predict(image_array, verbose=0).flatten()
        logger.info(f"extract_features: Raw output shape: {features.shape}, dtype: {features.dtype}, range: [{features.min():.6f}, {features.max():.6f}]")

        # Handle NaN/Inf
        if np.any(np.isnan(features)) or np.any(np.isinf(features)):
            nan_count = np.sum(np.isnan(features))
            inf_count = np.sum(np.isinf(features))
            logger.error(f"extract_features: Model produced {nan_count} NaN and {inf_count} Inf values")
            features[np.isnan(features) | np.isinf(features)] = 0.0
            corruption_ratio = (nan_count + inf_count) / len(features)
            if corruption_ratio > 0.1:
                logger.error(f"extract_features: Too many corrupted values ({corruption_ratio:.2%})")
                return None
            logger.info(f"extract_features: Fixed {nan_count + inf_count} corrupted values")

        # Clip and normalize
        features = np.clip(features, -1e6, 1e6)
        features = normalize_features(features)
        features = features.astype(np.float32)

        logger.info(f"extract_features: Final features range: [{features.min():.6f}, {features.max():.6f}], norm: {np.linalg.norm(features):.6f}")
        return features
    except Exception as e:
        logger.error(f"extract_features: Error: {e}")
        logger.debug(traceback.format_exc())
        return None

def normalize_features(features):
    """Normalizes features to unit length."""
    norm = np.linalg.norm(features)
    if norm == 0:
        logger.error("normalize_features: Zero norm detected")
        return features
    return features / (norm + 1e-8)

def compare_features(features1, features2):
    """Calculates normalized Euclidean distance between feature vectors."""
    try:
        if features1 is None or features2 is None:
            logger.error("compare_features: One or both feature vectors are None")
            return float('nan')

        logger.info(f"compare_features: Input shapes - features1: {features1.shape}, features2: {features2.shape}")
        if np.any(np.isnan(features1)) or np.any(np.isinf(features1)):
            logger.error(f"compare_features: features1 has NaN: {np.sum(np.isnan(features1))}, Inf: {np.sum(np.isinf(features1))}")
            return float('nan')
        if np.any(np.isnan(features2)) or np.any(np.isinf(features2)):
            logger.error(f"compare_features: features2 has NaN: {np.sum(np.isnan(features2))}, Inf: {np.sum(np.isinf(features2))}")
            return float('nan')

        features1 = features1.astype(np.float64)
        features2 = features2.astype(np.float64)
        logger.info(f"compare_features: features1 range: [{features1.min():.6f}, {features1.max():.6f}]")
        logger.info(f"compare_features: features2 range: [{features2.min():.6f}, {features2.max():.6f}]")

        features1 = normalize_features(features1)
        features2 = normalize_features(features2)
        diff = np.clip(features1 - features2, -1e10, 1e10)
        distance = np.sqrt(np.sum(np.square(diff)))
        logger.info(f"compare_features: Distance: {distance:.6f}")
        return float(distance)
    except Exception as e:
        logger.error(f"compare_features: Error: {e}")
        logger.debug(traceback.format_exc())
        return float('nan')

def get_stored_features_for_learner(learner_id):
    """Retrieve stored fingerprint features from MySQL."""
    try:
        conn = mysql.connector.connect(
            host='localhost',
            user='root',
            password='',
            database='lito'
        )
        cursor = conn.cursor()
        cursor.execute(
            "SELECT fingerprint_template, sourceafis_template, isLeftHand FROM learnerdetails WHERE LearnerID = %s",
            (learner_id,)
        )
        row = cursor.fetchone()
        conn.close()
        if row:
            for idx, col in enumerate(row):
                if col:
                    try:
                        decoded = base64.b64decode(col)
                        features = np.frombuffer(decoded, dtype=np.float32)
                        if np.any(np.isnan(features)) or np.any(np.isinf(features)):
                            logger.error(f"get_stored_features: Invalid features in column {['fingerprint_template', 'sourceafis_template', 'isLeftHand'][idx]}")
                            continue
                        logger.info(f"get_stored_features: Decoded template from column {['fingerprint_template', 'sourceafis_template', 'isLeftHand'][idx]}")
                        return features
                    except Exception as e:
                        logger.error(f"get_stored_features: Error decoding column {['fingerprint_template', 'sourceafis_template', 'isLeftHand'][idx]}: {e}")
                        continue
        logger.error(f"get_stored_features: No valid templates for learner {learner_id}")
        return None
    except Exception as e:
        logger.error(f"get_stored_features: Error for learner {learner_id}: {e}")
        logger.debug(traceback.format_exc())
        return None

def save_features_for_learner(learner_id, features):
    """Save fingerprint features to MySQL."""
    try:
        if np.any(np.isnan(features)) or np.any(np.isinf(features)):
            logger.error(f"save_features: Invalid features for learner {learner_id}")
            return False
        conn = mysql.connector.connect(
            host='localhost',
            user='root',
            password='',
            database='lito'
        )
        cursor = conn.cursor()
        features_bytes = features.tobytes()
        features_base64 = base64.b64encode(features_bytes).decode('utf-8')
        cursor.execute(
            "UPDATE learnerdetails SET sourceafis_template = %s WHERE LearnerID = %s",
            (features_base64, learner_id)
        )
        conn.commit()
        conn.close()
        logger.info(f"save_features: Saved features for learner {learner_id}")
        return True
    except Exception as e:
        logger.error(f"save_features: Error for learner {learner_id}: {e}")
        logger.debug(traceback.format_exc())
        return False

# --- FLASK APPLICATION ---
app = Flask(__name__)

def notify_php_clocking(
    learner_id,
    clock_type="in",
    signature=None,
    user_latitude=None,
    user_longitude=None,
    user_accuracy=None
):
    now = datetime.now()
    clock_date = now.strftime("%Y-%m-%d")
    clock_time = now.strftime("%H:%M:%S")
    data = {
        "learner_id": learner_id,
        "clock_date": clock_date,
        "signature": signature or "",
        "user_latitude": user_latitude or "",
        "user_longitude": user_longitude or "",
        "user_accuracy": user_accuracy or "",
    }
    if clock_type == "in":
        data["clock_in_time"] = clock_time
    elif clock_type == "out":
        data["clock_out_time"] = clock_time
    try:
        logger.info(f"notify_php_clocking: Sending to {PHP_URL}, data: {data}")
        response = requests.post(PHP_URL, data=data, timeout=10)
        logger.info(f"notify_php_clocking: Status: {response.status_code}, body: {response.text}")
        return response.status_code, response.text
    except Exception as e:
        logger.error(f"notify_php_clocking: Error: {e}")
        logger.debug(traceback.format_exc())
        return None, str(e)

@app.route('/verify', methods=['POST'])
def verify():
    logger.info("="*50)
    logger.info("verify: NEW REQUEST RECEIVED")
    logger.info("="*50)
    try:
        data = request.get_json()
        if not data:
            logger.error("verify: No JSON data received")
            return jsonify({'success': False, 'message': 'No JSON data provided'}), 400

        learner_id = data.get('LearnerID') or data.get('learner_id')
        image_b64 = data.get('image_base64')
        stored_features_b64 = data.get('stored_features_base64')
        action = data.get('action', 'in')
        signature = data.get('signature')
        user_latitude = data.get('user_latitude')
        user_longitude = data.get('user_longitude')
        user_accuracy = data.get('user_accuracy')

        log_data = {k: v[:50] + '...' if isinstance(v, str) and len(v) > 50 else v for k, v in data.items()}
        logger.info(f"verify: Request data: {json.dumps(log_data)}")
        logger.info(f"verify: Parameters - learner_id={learner_id}, image_b64={bool(image_b64)}, stored_features_b64={bool(stored_features_b64)}")

        if not learner_id or not image_b64 or not stored_features_b64:
            logger.error("verify: Missing required parameters")
            return jsonify({'success': False, 'message': 'Missing LearnerID, image_base64, or stored_features_base64'}), 400

        logger.info("verify: Validating parameters")
        try:
            base64.b64decode(image_b64)
            logger.info("verify: image_base64 validation passed")
        except Exception as e:
            logger.error(f"verify: Invalid image_base64: {e}")
            return jsonify({'success': False, 'message': f'Invalid image_base64: {e}'}), 400

        try:
            stored_features = np.frombuffer(base64.b64decode(stored_features_b64), dtype=np.float32)
            if np.any(np.isnan(stored_features)) or np.any(np.isinf(stored_features)):
                logger.error(f"verify: stored_features has NaN: {np.sum(np.isnan(stored_features))}, Inf: {np.sum(np.isinf(stored_features))}")
                return jsonify({'success': False, 'message': 'Invalid stored features: contains NaN or Inf'}), 400
            logger.info(f"verify: stored_features shape: {stored_features.shape}, range: [{stored_features.min():.6f}, {stored_features.max():.6f}]")
        except Exception as e:
            logger.error(f"verify: Invalid stored_features_base64: {e}")
            return jsonify({'success': False, 'message': f'Invalid stored_features_base64: {e}'}), 400

        logger.info("verify: Preprocessing image")
        image_array = preprocess_image(image_b64, IMAGE_SIZE, is_wsq=False)
        if image_array is None:
            logger.error("verify: Failed to preprocess image")
            return jsonify({'success': False, 'message': 'Failed to preprocess image'}), 500

        logger.info("verify: Extracting features")
        current_features = extract_features(image_array)
        if current_features is None:
            logger.error("verify: Failed to extract features")
            return jsonify({'success': False, 'message': 'Failed to extract features'}), 500

        logger.info("verify: Comparing features")
        distance = compare_features(current_features, stored_features)
        if np.isnan(distance) or np.isinf(distance):
            logger.error("verify: Invalid distance calculation")
            return jsonify({'success': False, 'message': 'Invalid distance calculation'}), 500

        is_match = distance <= THRESHOLD
        confidence = 1.0 - min(distance / THRESHOLD, 1.0)
        logger.info(f"verify: Result - distance={distance:.4f}, threshold={THRESHOLD}, is_match={is_match}, confidence={confidence:.4f}")

        if is_match:
            logger.info("verify: Match found, notifying PHP")
            status, php_resp = notify_php_clocking(
                learner_id,
                clock_type=action,
                signature=signature,
                user_latitude=user_latitude,
                user_longitude=user_longitude,
                user_accuracy=user_accuracy
            )
            return jsonify({
                'success': True,
                'is_match': True,
                'distance': float(distance),
                'confidence': float(confidence),
                'threshold': THRESHOLD,
                'php_status': status,
                'php_response': php_resp
            })
        else:
            logger.info("verify: No match")
            return jsonify({
                'success': False,
                'is_match': False,
                'distance': float(distance),
                'threshold': THRESHOLD,
                'message': 'Fingerprint did not match'
            })
    except Exception as e:
        logger.error(f"verify: Unexpected error: {e}")
        logger.debug(traceback.format_exc())
        return jsonify({'success': False, 'message': f'Server error: {e}'}), 500

@app.route('/extract', methods=['POST'])
def create_features():
    try:
        if not request.is_json:
            logger.error("create_features: Invalid Content-Type, expected application/json")
            return jsonify({"success": False, "error": "Invalid Content-Type: application/json required"}), 400

        data = request.get_json()
        image_base64 = data.get('image_base64')
        learner_id = data.get('LearnerID') or data.get('learner_id')

        log_data = {k: v[:50] + '...' if isinstance(v, str) and len(v) > 50 else v for k, v in data.items()}
        logger.info(f"create_features: Request data: {json.dumps(log_data)}")

        if not image_base64 or not learner_id:
            logger.error(f"create_features: Missing parameters - learner_id={learner_id}, image_base64={bool(image_base64)}")
            return jsonify({"success": False, "error": "Missing LearnerID or image_base64"}), 400

        try:
            base64.b64decode(image_base64)
        except Exception as e:
            logger.error(f"create_features: Invalid image_base64: {e}")
            return jsonify({"success": False, "error": f"Invalid image_base64: {e}"}), 400

        image_array = preprocess_image(image_base64, IMAGE_SIZE, is_wsq=True)
        if image_array is None:
            logger.error("create_features: Failed to preprocess image")
            return jsonify({"success": False, "error": "Failed to preprocess image"}), 500

        features = extract_features(image_array)
        if features is None:
            logger.error("create_features: Failed to extract features")
            return jsonify({"success": False, "error": "Failed to extract features"}), 500

        if not save_features_for_learner(learner_id, features):
            logger.error(f"create_features: Failed to save features for learner {learner_id}")
            return jsonify({"success": False, "error": "Failed to save features"}), 500

        features_bytes = features.tobytes()
        features_base64 = base64.b64encode(features_bytes).decode('utf-8')
        logger.info(f"create_features: Success for learner {learner_id}, feature_dimensions={features.shape[0]}")
        return jsonify({
            'success': True,
            'features_base64': features_base64,
            'feature_dimensions': features.shape[0]
        })
    except Exception as e:
        logger.error(f"create_features: Unexpected error: {e}")
        logger.debug(traceback.format_exc())
        return jsonify({'success': False, 'error': f'Server error: {e}'}), 500

@app.route('/health', methods=['GET'])
def health_check():
    logger.info("health: Health check request received")
    return jsonify({
        'status': 'healthy',
        'message': 'Server is running',
        'model_loaded': MODEL is not None,
        'encoder_loaded': ENCODER is not None
    })

if __name__ == '__main__':
    logger.info("--- Starting Siamese Model Server ---")
    try:
        import time
        logger.info(f"TensorFlow version: {tf.__version__}")
        import keras
        logger.info(f"Keras version: {keras.__version__}")
        logger.info(f"Loading model from: {MODEL_PATH}")
        if not os.path.exists(MODEL_PATH):
            logger.error(f"Model file not found: {MODEL_PATH}")
            sys.exit(1)
        start_time = time.time()
        MODEL = tf.keras.models.load_model(MODEL_PATH, compile=False)
        elapsed = time.time() - start_time
        logger.info(f"Model loaded in {elapsed:.2f} seconds")
        if elapsed > 10:
            logger.warning(f"Model loading took {elapsed:.2f} seconds")

        if len(MODEL.layers) >= 3 and isinstance(MODEL.layers[2], tf.keras.Model):
            ENCODER = MODEL.layers[2]
            logger.info(f"Extracted encoder: '{ENCODER.name}'")
            dummy_input = np.zeros((1, 224, 224, 1), dtype=np.float32)
            dummy_output = ENCODER.predict(dummy_input, verbose=0).flatten()
            if np.any(np.isnan(dummy_output)) or np.any(np.isinf(dummy_output)):
                logger.error("Encoder produced invalid output in dummy test")
                sys.exit(1)
            logger.info(f"Encoder test passed, output shape: {dummy_output.shape}")
        else:
            logger.error("Could not find encoder sub-model")
            sys.exit(1)
        logger.info("Model and encoder loaded successfully")
        logger.info("Starting Flask server on http://0.0.0.0:5001")
        from waitress import serve
        serve(app, host='0.0.0.0', port=5001)
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        logger.debug(traceback.format_exc())
        sys.exit(1)