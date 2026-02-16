import h5py

MODEL_PATH = 'C:/xampp/htdocs/mobile/models/siamese_model_checkpoint.h5'

with h5py.File(MODEL_PATH, 'r') as f:
    keras_version = f.attrs.get('keras_version', '')
    if isinstance(keras_version, bytes):
        keras_version = keras_version.decode('utf-8')
    backend = f.attrs.get('backend', '')
    if isinstance(backend, bytes):
        backend = backend.decode('utf-8')
    print(f"Model file Keras version: {keras_version}")
    print(f"Model file backend: {backend}")
