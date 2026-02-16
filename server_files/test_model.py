import tensorflow as tf
import numpy as np
import cv2
model = tf.keras.models.load_model('C:\xampp\htdocs\mobile\models\siamese_model_checkpoint.h5')
img = cv2.imread('sample_image.png', cv2.IMREAD_GRAYSCALE)
img = cv2.resize(img, (224, 224)).astype('float32') / 255.0
img = np.expand_dims(img, axis=[0, -1])
features = model.predict(img, batch_size=1)
print(f"Features shape: {features.shape}, has NaN: {np.any(np.isnan(features))}, has inf: {np.any(np.isinf(features))}")