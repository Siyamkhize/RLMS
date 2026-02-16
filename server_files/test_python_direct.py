import base64
import json
import subprocess
import sys
import os

# Path to your sample image (update this to a real image path)
SAMPLE_IMAGE_PATH = 'sample_fingerprint.jpg'  # <-- Changed to .jpg

# Path to the extract_features.py script
EXTRACT_SCRIPT = 'server_files/extract_features.py'  # <-- Updated path

# Read and encode the image as base64
def encode_image_to_base64(image_path):
    with open(image_path, 'rb') as img_file:
        return base64.b64encode(img_file.read()).decode('utf-8')

def main():
    if not os.path.exists(SAMPLE_IMAGE_PATH):
        print(f"Sample image not found: {SAMPLE_IMAGE_PATH}")
        sys.exit(1)
    
    image_b64 = encode_image_to_base64(SAMPLE_IMAGE_PATH)
    input_data = {'image_base64': image_b64}
    
    # Write to a temp file
    temp_json = 'test_input.json'
    with open(temp_json, 'w') as f:
        json.dump(input_data, f)
    
    # Run the extract_features.py script
    print(f"Running: python {EXTRACT_SCRIPT} {temp_json}")
    result = subprocess.run([sys.executable, EXTRACT_SCRIPT, temp_json], capture_output=True, text=True)
    print("--- STDOUT ---")
    print(result.stdout)
    print("--- STDERR ---")
    print(result.stderr)
    
    # Clean up temp file
    os.remove(temp_json)

if __name__ == '__main__':
    main() 