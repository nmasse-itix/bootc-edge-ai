import numpy as np
import time
import onnxruntime as ort
import json
import os
import logging
import ast
import cv2.dnn

# Environment variables
MODEL_PATH = os.environ.get("MODEL_PATH", "model.onnx")
INPUT_IMAGE_PATH = os.environ.get("IMAGE_PATH", "input.jpg")

# Onnxruntime providers
PROVIDERS = ast.literal_eval(os.environ.get("ONNXRUNTIME_PROVIDERS", '["CUDAExecutionProvider"]'))

CLASSES = {
  0: "SpeedLimit",
  1: "DangerAhead"
}
colors = np.random.uniform(0, 255, size=(len(CLASSES), 3))
MIN_CONF_THRESHOLD = float(os.environ.get("MIN_CONF_THRESHOLD", 0.8))


def preprocess(original_image):
    # original_image: np.ndarray = cv2.imread(image_path)
    [height, width, _] = original_image.shape

    # Prepare a square image for inference
    length = max((height, width))
    image = np.zeros((length, length, 3), np.uint8)
    image[0:height, 0:width] = original_image

    # Calculate scale factor
    scale = length / 640

    # Preprocess the image and prepare blob for model
    blob = cv2.dnn.blobFromImage(image, scalefactor=1 / 255, size=(640, 640), swapRB=True)
    return blob, scale, original_image

def postprocess(response):
    outputs = np.array([cv2.transpose(response[0])])
    rows = outputs.shape[1]

    boxes = []
    scores = []
    class_ids = []

    # Iterate through output to collect bounding boxes, confidence scores, and class IDs
    for i in range(rows):
        classes_scores = outputs[0][i][4:]
        (minScore, maxScore, minClassLoc, (x, maxClassIndex)) = cv2.minMaxLoc(classes_scores)
        if maxScore >= 0.25:
            box = [
                outputs[0][i][0] - (0.5 * outputs[0][i][2]), outputs[0][i][1] - (0.5 * outputs[0][i][3]),
                outputs[0][i][2], outputs[0][i][3]]
            boxes.append(box)
            scores.append(maxScore)
            class_ids.append(maxClassIndex)

    detections = []
    result_boxes = cv2.dnn.NMSBoxes(boxes, scores, 0.25, 0.45, 0.5)
    # Iterate through NMS results to draw bounding boxes and labels
    for i in range(len(result_boxes)):
        index = result_boxes[i]
        box = boxes[index]
        if scores[index] > MIN_CONF_THRESHOLD:
            detection = {
                'class_id': class_ids[index],
                'class_name': CLASSES[class_ids[index]],
                'confidence': f"{scores[index]:.2f}",
                'box': [f"{c:.2f}" for c in box]}
            detections.append(detection)
    return detections

if __name__ == "__main__":
    # Logger
    logging.basicConfig(
        format='%(asctime)s %(levelname)-8s %(message)s',
        level=logging.INFO,
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    logger = logging.getLogger(__name__)
    ort_sess = ort.InferenceSession(MODEL_PATH, providers=PROVIDERS)
    nparr = np.fromfile(INPUT_IMAGE_PATH, np.uint8)
    nparr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    preprocessed, scale, original_image = preprocess(nparr)
    outputs = ort_sess.run(None, {'images': preprocessed})
    detections = postprocess(outputs[0])
    logger.info(f"Processed image {INPUT_IMAGE_PATH}")
    logger.info(json.dumps(detections))
    logger.info(f"Now starting mass inference...")
    start = time.time()
    count = 0
    while True:
        now = time.time()
        if now - start > 1:
            logger.info(f"Performed {count} inferences in {now-start:.2f}s")
            start = time.time()
            count = 0
        outputs = ort_sess.run(None, {'images': preprocessed})
        count+=1

