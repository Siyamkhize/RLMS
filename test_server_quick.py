import requests
import json
import base64
from PIL import Image
import io

# Create a simple test fingerprint-like image
def create_test_image():
    # Create a simple 96x96 grayscale image
    img = Image.new('L', (96, 96), color=128)  # Gray image
    
    # Add some pattern to simulate fingerprint ridges
    for y in range(96):
        for x in range(96):
            if (x + y) % 8 < 4:  # Simple pattern
                img.putpixel((x, y), 200)
    
    # Convert to PNG bytes
    buffer = io.BytesIO()
    img.save(buffer, format='PNG')
    return buffer.getvalue()

def test_extract_features():
    print("Creating test fingerprint image...")
    png_bytes = create_test_image()
    image_base64 = base64.b64encode(png_bytes).decode('utf-8')
    
    print(f"Test image size: {len(png_bytes)} bytes")
    print(f"Base64 size: {len(image_base64)} characters")
    
    test_data = {
        "image_base64": image_base64
    }
    
    try:
        print("Sending request to extract_features.php...")
        print("This may take up to 3 minutes for model loading...")
        
        response = requests.post(
            'http://192.168.0.53/mobile/extract_features.php',
            headers={'Content-Type': 'application/json'},
            data=json.dumps(test_data),
            timeout=200  # Give extra time
        )
        
        print(f"Response Status: {response.status_code}")
        print(f"Response Headers: {dict(response.headers)}")
        print(f"Response Body: {response.text}")
        
        if response.status_code == 200:
            try:
                result = response.json()
                print(f"Parsed JSON: {result}")
                
                if result.get('success'):
                    print("✅ Feature extraction successful!")
                    if 'features_base64' in result:
                        features_data = base64.b64decode(result['features_base64'])
                        print(f"Features size: {len(features_data)} bytes")
                else:
                    print(f"❌ Server error: {result.get('error', 'Unknown error')}")
            except json.JSONDecodeError as e:
                print(f"❌ JSON decode error: {e}")
        else:
            print(f"❌ HTTP error: {response.status_code}")
            
    except requests.exceptions.Timeout:
        print("❌ Request timed out - model loading may be taking too long")
    except requests.exceptions.ConnectionError:
        print("❌ Connection error - check if XAMPP server is running")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")

if __name__ == "__main__":
    test_extract_features() 