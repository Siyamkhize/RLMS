# Siamese Model Integration for Contactless Fingerprint Verification

This document describes the integration of a trained Siamese neural network model for contactless fingerprint verification in the RLMS application.

## Overview

The Siamese model integration enables:
1. **Feature Extraction**: Extracting fingerprint features from captured images during enrollment
2. **Feature Verification**: Comparing captured fingerprint images against stored templates during clock-in/out

## Architecture

### Components

1. **Flutter App (`contact_less.dart`)**
   - Captures fingerprint images using camera
   - Calls server APIs for feature extraction and verification
   - Manages enrollment and verification workflows

2. **PHP API Endpoints**
   - `siamese_inference.php`: Handles fingerprint verification
   - `extract_features.php`: Handles feature extraction during enrollment

3. **Python Scripts**
   - `python_inference.py`: Main inference script for verification
   - `extract_features.py`: Feature extraction script for enrollment
   - `test_siamese_integration.py`: Test script for validation

4. **Database Integration**
   - Uses `sourceafis_template` and `isLeftHand` columns in `learnerdetails` table
   - Stores feature vectors as base64-encoded strings

## API Endpoints

### 1. Feature Extraction (Enrollment)
```
POST http://192.168.0.53/mobile/extract_features.php
Content-Type: application/json

{
  "image_base64": "base64_encoded_fingerprint_image"
}

Response:
{
  "success": true,
  "features_base64": "base64_encoded_feature_vector",
  "feature_dimensions": 128
}
```

### 2. Fingerprint Verification (Clock-in/out)
```
POST http://192.168.0.53/mobile/siamese_inference.php
Content-Type: application/json

{
  "image_base64": "base64_encoded_captured_image",
  "stored_features_base64": "base64_encoded_stored_features"
}

Response:
{
  "success": true,
  "similarity": 0.85,
  "is_match": true,
  "threshold": 0.5
}
```

## Database Schema

The system uses the existing `learnerdetails` table with these columns:

- `sourceafis_template`: Stores feature vectors for primary fingerprint template
- `isLeftHand`: Stores feature vectors for secondary fingerprint template

Both columns store base64-encoded feature vectors extracted by the Siamese model.

## Workflow

### Enrollment Process
1. User captures fingerprint image using camera
2. Image is sent to `extract_features.php`
3. Python script extracts features using Siamese model encoder
4. Features are stored in database as base64 string
5. User receives confirmation of successful enrollment

### Verification Process
1. User captures fingerprint image during clock-in/out
2. System retrieves stored templates from database
3. Image is sent to `siamese_inference.php` with stored features
4. Python script compares features using Siamese model
5. System returns similarity score and match decision
6. If match is found, clock-in/out proceeds

## Model Requirements

### Model File
- **Path**: `C:/xampp/htdocs/mobile/models/siamese_model_checkpoint.h5`
- **Format**: Keras HDF5 model file
- **Input**: 96x96 grayscale fingerprint images
- **Output**: Feature vectors for comparison

### Model Architecture
The Siamese model should have:
- Encoder network for feature extraction
- Comparator network for similarity calculation
- Output layer producing similarity scores

## Configuration

### Model Path
Update the model path in both Python scripts:
```python
model_path = 'C:/xampp/htdocs/mobile/models/siamese_model_checkpoint.h5'
```

### Threshold Settings
Adjust similarity threshold in `python_inference.py`:
```python
threshold = 0.5  # Adjust based on model performance
```

### Image Preprocessing
- **Size**: 96x96 pixels
- **Format**: Grayscale
- **Normalization**: Values scaled to [0, 1]

## Testing

### Run Test Script
```bash
cd server_files
python test_siamese_integration.py
```

### Manual Testing
1. **Enrollment Test**:
   - Capture fingerprint image
   - Call `extract_features.php`
   - Verify features are stored in database

2. **Verification Test**:
   - Capture fingerprint image
   - Call `siamese_inference.php`
   - Verify similarity score and match decision

## Error Handling

### Common Issues
1. **Model Not Found**: Ensure model file exists at specified path
2. **Python Dependencies**: Install required packages (tensorflow, pillow, numpy)
3. **Memory Issues**: Model caching reduces memory usage
4. **Timeout**: Increase PHP execution time limits

### Debug Logging
All Python scripts include debug logging to stderr:
```python
print("Debug message", file=sys.stderr)
```

## Performance Optimization

### Model Caching
- Model is loaded once and cached in memory
- Subsequent calls use cached model
- Reduces loading time significantly

### Batch Processing
- Process multiple images in single model call
- Reduces overhead for bulk operations

### Memory Management
- Use `verbose=0` in model.predict() to reduce output
- Clear model cache if memory issues occur

## Security Considerations

### Input Validation
- Validate base64 encoding
- Check image dimensions
- Sanitize file paths

### Error Messages
- Don't expose internal model paths in error messages
- Log detailed errors for debugging
- Return generic error messages to clients

## Troubleshooting

### Model Loading Issues
1. Check model file path
2. Verify TensorFlow version compatibility
3. Check available memory

### Feature Extraction Issues
1. Verify image preprocessing
2. Check model input shape
3. Validate base64 encoding

### Verification Issues
1. Check similarity threshold
2. Verify feature vector dimensions
3. Test with known good templates

## Future Enhancements

1. **Model Optimization**: Quantize model for faster inference
2. **Batch Processing**: Support multiple verifications simultaneously
3. **Model Updates**: Implement model versioning and updates
4. **Performance Monitoring**: Add metrics collection and monitoring
5. **Fallback Mechanisms**: Implement alternative verification methods

## Dependencies

### Python Packages
```
tensorflow>=2.0.0
pillow>=8.0.0
numpy>=1.19.0
```

### PHP Requirements
- PHP 7.4+
- JSON extension
- File system access

### System Requirements
- Windows/Linux with Python 3.7+
- Sufficient RAM for model loading (2GB+ recommended)
- GPU support optional but recommended for performance 