import tempfile
import json

# Create test data
test_data = {
    "image_base64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
}

# Write to temp file
temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json')
temp_file.write(json.dumps(test_data))
temp_file.close()

print(f"Created temp file: {temp_file.name}")
print(f"Temp file contents: {json.dumps(test_data)}")

# Test the Python script directly
import subprocess
import sys

try:
    result = subprocess.run([
        'python', 
        'C:/xampp/htdocs/mobile/scripts/extract_features.py',
        temp_file.name
    ], capture_output=True, text=True, timeout=300)
    
    print(f"Return code: {result.returncode}")
    print(f"STDOUT:\n{result.stdout}")
    print(f"STDERR:\n{result.stderr}")
    
except subprocess.TimeoutExpired:
    print("Script timed out after 5 minutes")
except Exception as e:
    print(f"Error running script: {e}")
finally:
    # Clean up
    import os
    try:
        os.unlink(temp_file.name)
        print(f"Cleaned up temp file: {temp_file.name}")
    except:
        pass 