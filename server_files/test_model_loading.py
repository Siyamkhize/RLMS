import os
import tensorflow as tf
import h5py
import sys
import time

MODEL_PATH = 'C:/xampp/htdocs/mobile/models/siamese_model_checkpoint.h5'

print(f"TensorFlow version: {tf.__version__}")
import keras
print(f"Keras version: {keras.__version__}")

if not os.path.exists(MODEL_PATH):
    print(f"Model file not found at {MODEL_PATH}")
    sys.exit(1)

# Try to read HDF5 attributes for version info
try:
    with h5py.File(MODEL_PATH, 'r') as f:
        keras_version = f.attrs.get('keras_version', b'').decode('utf-8')
        backend = f.attrs.get('backend', b'').decode('utf-8')
        print(f"Model file Keras version: {keras_version}")
        print(f"Model file backend: {backend}")
except Exception as e:
    print(f"Could not read model file attributes: {e}")

start_time = time.time()
try:
    model = tf.keras.models.load_model(MODEL_PATH, compile=False)
    print("Model loaded successfully!")
    print(model.summary())
except Exception as e:
    print(f"Exception while loading model: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
elapsed = time.time() - start_time
print(f"Model loading took {elapsed:.2f} seconds.")
if elapsed > 10:
    print(f"WARNING: Model loading took longer than expected ({elapsed:.2f} seconds)")
