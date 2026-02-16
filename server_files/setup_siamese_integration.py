#!/usr/bin/env python3
"""
Setup script for Siamese model integration
This script helps configure and deploy the Siamese model integration
"""

import os
import sys
import shutil
import json
from pathlib import Path

def check_python_dependencies():
    """Check if required Python packages are installed"""
    print("Checking Python dependencies...")
    
    required_packages = ['tensorflow', 'PIL', 'numpy']
    missing_packages = []
    
    for package in required_packages:
        try:
            if package == 'PIL':
                # Pillow is imported as PIL
                __import__('PIL')
                print(f"✓ pillow (PIL)")
            else:
                __import__(package)
                print(f"✓ {package}")
        except ImportError:
            if package == 'PIL':
                print(f"✗ pillow (PIL) - NOT FOUND")
                missing_packages.append('pillow')
            else:
                print(f"✗ {package} - NOT FOUND")
                missing_packages.append(package)
    
    if missing_packages:
        print(f"\nMissing packages: {', '.join(missing_packages)}")
        print("Please install missing packages using:")
        print(f"pip install {' '.join(missing_packages)}")
        return False
    
    print("All Python dependencies are installed!")
    return True

def check_model_file():
    """Check if the Siamese model file exists"""
    print("\nChecking model file...")
    
    model_path = 'C:/xampp/htdocs/mobile/models/siamese_model_checkpoint.h5'
    
    if os.path.exists(model_path):
        print(f"✓ Model file found at: {model_path}")
        file_size = os.path.getsize(model_path) / (1024 * 1024)  # MB
        print(f"  File size: {file_size:.1f} MB")
        return True
    else:
        print(f"✗ Model file not found at: {model_path}")
        print("Please ensure the trained Siamese model is placed at this location")
        return False

def check_php_endpoints():
    """Check if PHP endpoints are accessible"""
    print("\nChecking PHP endpoints...")
    
    endpoints = [
        'siamese_inference.php',
        'extract_features.php'
    ]
    
    all_found = True
    for endpoint in endpoints:
        if os.path.exists(endpoint):
            print(f"✓ {endpoint}")
        else:
            print(f"✗ {endpoint} - NOT FOUND")
            all_found = False
    
    return all_found

def create_model_directory():
    """Create the model directory if it doesn't exist"""
    print("\nCreating model directory...")
    
    model_dir = 'C:/xampp/htdocs/mobile/models'
    
    try:
        os.makedirs(model_dir, exist_ok=True)
        print(f"✓ Model directory created/verified: {model_dir}")
        return True
    except Exception as e:
        print(f"✗ Failed to create model directory: {e}")
        return False

def update_model_paths():
    """Update model paths in Python scripts"""
    print("\nUpdating model paths in Python scripts...")
    
    scripts = ['python_inference.py', 'extract_features.py']
    model_path = 'C:/xampp/htdocs/mobile/models/siamese_model_checkpoint.h5'
    
    for script in scripts:
        if os.path.exists(script):
            try:
                with open(script, 'r') as f:
                    content = f.read()
                
                # Replace model path
                updated_content = content.replace(
                    "model_path = 'C:/xampp/htdocs/mobile/models/siamese_model_checkpoint.h5'",
                    f"model_path = '{model_path}'"
                )
                
                with open(script, 'w') as f:
                    f.write(updated_content)
                
                print(f"✓ Updated {script}")
            except Exception as e:
                print(f"✗ Failed to update {script}: {e}")
        else:
            print(f"✗ {script} not found")

def create_test_config():
    """Create a test configuration file"""
    print("\nCreating test configuration...")
    
    config = {
        "model_path": "C:/xampp/htdocs/mobile/models/siamese_model_checkpoint.h5",
        "threshold": 0.5,
        "image_size": [96, 96],
        "api_endpoints": {
            "verification": "http://192.168.0.53/mobile/siamese_inference.php",
            "extraction": "http://192.168.0.53/mobile/extract_features.php"
        }
    }
    
    try:
        with open('siamese_config.json', 'w') as f:
            json.dump(config, f, indent=2)
        print("✓ Created siamese_config.json")
    except Exception as e:
        print(f"✗ Failed to create config file: {e}")

def run_tests():
    """Run integration tests"""
    print("\nRunning integration tests...")
    
    if os.path.exists('test_siamese_integration.py'):
        try:
            import subprocess
            result = subprocess.run([sys.executable, 'test_siamese_integration.py'], 
                                 capture_output=True, text=True)
            print("Test output:")
            print(result.stdout)
            if result.stderr:
                print("Test errors:")
                print(result.stderr)
        except Exception as e:
            print(f"✗ Failed to run tests: {e}")
    else:
        print("✗ Test script not found")

def main():
    """Main setup function"""
    print("=== Siamese Model Integration Setup ===")
    print("This script will help configure the Siamese model integration.\n")
    
    # Check dependencies
    deps_ok = check_python_dependencies()
    
    # Create model directory
    dir_ok = create_model_directory()
    
    # Check model file
    model_ok = check_model_file()
    
    # Check PHP endpoints
    php_ok = check_php_endpoints()
    
    # Update model paths
    update_model_paths()
    
    # Create test config
    create_test_config()
    
    # Run tests if everything is set up
    if deps_ok and model_ok and php_ok:
        run_tests()
    
    # Summary
    print("\n=== Setup Summary ===")
    print(f"Python dependencies: {'PASS' if deps_ok else 'FAIL'}")
    print(f"Model directory: {'PASS' if dir_ok else 'FAIL'}")
    print(f"Model file: {'PASS' if model_ok else 'FAIL'}")
    print(f"PHP endpoints: {'PASS' if php_ok else 'FAIL'}")
    
    if deps_ok and model_ok and php_ok:
        print("\n✓ Setup completed successfully!")
        print("The Siamese model integration should be ready to use.")
    else:
        print("\n✗ Setup incomplete. Please address the issues above.")
        print("Refer to README_SIAMESE_INTEGRATION.md for detailed instructions.")

if __name__ == '__main__':
    main() 