#!/usr/bin/env python3
"""
Test script for Siamese model integration
This script tests both feature extraction and verification functionality
"""

import sys
import json
import base64
import numpy as np
import tensorflow as tf
from PIL import Image
import io
import os
from datetime import datetime

def test_model_loading():
    """Test if the Siamese model can be loaded"""
    print("Testing model loading...")
    
    model_path = 'C:/xampp/htdocs/mobile/models/siamese_model_checkpoint.h5'
    
    if not os.path.exists(model_path):
        print(f"ERROR: Model file not found at {model_path}")
        return False
    
    try:
        model = tf.keras.models.load_model(model_path, compile=False)
        print(f"SUCCESS: Model loaded successfully")
        print(f"Model summary:")
        model.summary()
        return True
    except Exception as e:
        print(f"ERROR: Failed to load model: {e}")
        return False

def test_feature_extraction():
    """Test feature extraction from a sample image"""
    print("\nTesting feature extraction...")
    
    # Create a sample fingerprint-like image
    sample_image = Image.new('L', (96, 96), 128)  # Gray image
    sample_image_bytes = io.BytesIO()
    sample_image.save(sample_image_bytes, format='PNG')
    sample_image_base64 = base64.b64encode(sample_image_bytes.getvalue()).decode('utf-8')
    
    # Test the feature extraction process
    try:
        # Load model
        model_path = 'C:/xampp/htdocs/mobile/models/siamese_model_checkpoint.h5'
        model = tf.keras.models.load_model(model_path, compile=False)
        
        # Preprocess image
        image_data = base64.b64decode(sample_image_base64)
        image = Image.open(io.BytesIO(image_data))
        image = image.convert('L')
        image = image.resize((96, 96))
        img_array = np.array(image, dtype=np.float32) / 255.0
        img_array = np.expand_dims(img_array, axis=0)
        img_array = np.expand_dims(img_array, axis=-1)
        
        # Extract features
        features = model.predict(img_array, verbose=0)
        features_flat = features.flatten()
        
        print(f"SUCCESS: Features extracted successfully")
        print(f"Feature dimensions: {features_flat.shape}")
        print(f"Feature range: {features_flat.min():.4f} to {features_flat.max():.4f}")
        
        return True, features_flat
        
    except Exception as e:
        print(f"ERROR: Feature extraction failed: {e}")
        return False, None

def test_feature_comparison():
    """Test feature comparison functionality"""
    print("\nTesting feature comparison...")
    
    # Extract features from two similar images
    success1, features1 = test_feature_extraction()
    success2, features2 = test_feature_extraction()
    
    if not success1 or not success2:
        print("ERROR: Could not extract features for comparison")
        return False
    
    try:
        # Compare features using cosine similarity
        features1_norm = features1.reshape(1, -1)
        features2_norm = features2.reshape(1, -1)
        
        similarity = np.dot(features1_norm, features2_norm.T) / (
            np.linalg.norm(features1_norm) * np.linalg.norm(features2_norm)
        )
        
        similarity_score = float(similarity[0][0])
        print(f"SUCCESS: Feature comparison completed")
        print(f"Similarity score: {similarity_score:.4f}")
        
        # Test threshold
        threshold = 0.5
        is_match = similarity_score >= threshold
        print(f"Match result (threshold {threshold}): {is_match}")
        
        return True
        
    except Exception as e:
        print(f"ERROR: Feature comparison failed: {e}")
        return False

def test_api_endpoints():
    """Test the PHP API endpoints"""
    print("\nTesting API endpoints...")
    
    # This would require HTTP requests to the PHP endpoints
    # For now, just print the expected endpoints
    print("Expected API endpoints:")
    print("- POST http://192.168.0.53/mobile/siamese_inference.php")
    print("- POST http://192.168.0.53/mobile/extract_features.php")
    print("These endpoints should be tested manually with actual HTTP requests")

def main():
    """Run all tests"""
    print("=== Siamese Model Integration Test ===")
    print(f"Test started at: {datetime.now()}")
    
    # Test 1: Model loading
    model_ok = test_model_loading()
    
    # Test 2: Feature extraction
    extraction_ok = False
    if model_ok:
        extraction_ok, _ = test_feature_extraction()
    
    # Test 3: Feature comparison
    comparison_ok = False
    if extraction_ok:
        comparison_ok = test_feature_comparison()
    
    # Test 4: API endpoints info
    test_api_endpoints()
    
    # Summary
    print("\n=== Test Summary ===")
    print(f"Model loading: {'PASS' if model_ok else 'FAIL'}")
    print(f"Feature extraction: {'PASS' if extraction_ok else 'FAIL'}")
    print(f"Feature comparison: {'PASS' if comparison_ok else 'FAIL'}")
    
    if model_ok and extraction_ok and comparison_ok:
        print("\nSUCCESS: All core functionality tests passed!")
        print("The Siamese model integration should work correctly.")
    else:
        print("\nFAILURE: Some tests failed. Please check the errors above.")
        print("The Siamese model integration may not work correctly.")

if __name__ == '__main__':
    main() 