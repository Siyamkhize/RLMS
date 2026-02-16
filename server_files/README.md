# Server Files Deployment Guide

These files need to be deployed on your server (http://192.168.0.53) to use your Siamese model without converting to TensorFlow Lite.

## Files Overview

1. **extract_features.php** - PHP endpoint for feature extraction (enrollment)
2. **siamese_inference.php** - PHP endpoint for fingerprint matching
3. **extract_features.py** - Python script for feature extraction
4. **python_inference.py** - Python script for matching

## Deployment Steps

### 1. Server Requirements

```bash
# Install Python dependencies
pip install tensorflow pillow numpy

# Ensure PHP has shell_exec enabled
# Check php.ini: shell_exec should not be in disable_functions
```

### 2. File Deployment

```bash
# Copy PHP files to your web server directory
cp extract_features.php /var/www/html/mobile/
cp siamese_inference.php /var/www/html/mobile/

# Copy Python scripts to a secure location
mkdir -p /home/server/scripts/
cp extract_features.py /home/server/scripts/
cp python_inference.py /home/server/scripts/

# Make Python scripts executable
chmod +x /home/server/scripts/*.py
```

### 3. Upload Your Model

```bash
# Create models directory
mkdir -p /home/server/models/

# Copy your Siamese model
cp siamese_model_checkpoint.h5 /home/server/models/
```

### 4. Update File Paths

#### In PHP files:
Update these lines in both `extract_features.php` and `siamese_inference.php`:

```php
// Current line:
$python_script = '/home/server/scripts/extract_features.py';

// Update to your actual path:
$python_script = '/your/actual/path/to/extract_features.py';
```

#### In Python files:
Update this line in both `extract_features.py` and `python_inference.py`:

```python
# Current line:
model_path = '/home/server/models/siamese_model_checkpoint.h5'

# Update to your actual path:
model_path = '/your/actual/path/to/siamese_model_checkpoint.h5'
```

### 5. Set Permissions

```bash
# For Apache
chown www-data:www-data /home/server/scripts/*.py
chown www-data:www-data /home/server/models/*.h5

# For Nginx
chown nginx:nginx /home/server/scripts/*.py
chown nginx:nginx /home/server/models/*.h5
```

### 6. Test Endpoints

```bash
# Test feature extraction
curl -X POST http://192.168.0.53/mobile/extract_features.php \
  -H "Content-Type: application/json" \
  -d '{"image_base64":"iVBORw0KGgoAAAANS..."}'

# Test matching
curl -X POST http://192.168.0.53/mobile/siamese_inference.php \
  -H "Content-Type: application/json" \
  -d '{"image_base64":"iVBORw0KGgoAAAANS...", "stored_features_base64":"AAAA..."}'
```

## Model Configuration

### Target Size
If your model expects a different input size than 96x96, update this in both Python files:

```python
def preprocess_image(image_base64, target_size=(96, 96)):
# Change to your model's input size, e.g.:
def preprocess_image(image_base64, target_size=(128, 128)):
```

### Feature Extraction
The `extract_features()` function assumes your model can extract features from a single input. If your Siamese model has separate encoder/decoder parts, you may need to modify this function to use only the encoder part.

### Similarity Threshold
Adjust the matching threshold in `python_inference.py`:

```python
# Current:
threshold = 0.5

# Adjust based on your model's performance:
threshold = 0.7  # More strict
# or
threshold = 0.3  # More lenient
```

## Troubleshooting

### Common Issues:

1. **"shell_exec disabled"**
   - Edit php.ini and remove shell_exec from disable_functions
   - Restart web server

2. **"Permission denied"**
   - Check file permissions and ownership
   - Ensure web server can execute Python scripts

3. **"Model not found"**
   - Verify model path is correct
   - Check file permissions

4. **"Import errors"**
   - Ensure all Python dependencies are installed
   - Use virtual environment if needed

### Debug Mode
Add this to the top of PHP files for debugging:

```php
error_reporting(E_ALL);
ini_set('display_errors', 1);
```

## Security Notes

- Place Python scripts outside web root
- Validate input data
- Consider rate limiting
- Use HTTPS in production
- Implement authentication if needed

## Success!

Once deployed, your Flutter app will use server-side inference with your original Siamese .h5 model - no TensorFlow Lite conversion needed! 