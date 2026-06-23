import cv2
import json
import time
import os
from ultralytics import YOLO
try:
    import pyttsx3
    tts_engine = pyttsx3.init()
except Exception:
    tts_engine = None

class PythonVehicleTracker:
    def __init__(self):
        self.tracked_objects = {}  # id -> {label, bbox, distance, is_approaching, area_growth_streak, last_seen}
        self.max_lost_frames = 5
        self.iou_threshold = 0.25
        self.frame_count = 0

    def calculate_iou(self, boxA, boxB):
        # Coordinates: [left, top, right, bottom]
        xA = max(boxA[0], boxB[0])
        yA = max(boxA[1], boxB[1])
        xB = min(boxA[2], boxB[2])
        yB = min(boxA[3], boxB[3])
        
        inter_area = max(0, xB - xA) * max(0, yB - yA)
        if inter_area == 0:
            return 0.0
            
        areaA = (boxA[2] - boxA[0]) * (boxA[3] - boxA[1])
        areaB = (boxB[2] - boxB[0]) * (boxB[3] - boxB[1])
        return inter_area / float(areaA + areaB - inter_area)

    def estimate_distance(self, bbox, label, frame_height):
        # Normalize height relative to image viewport
        height_ratio = (bbox[3] - bbox[1]) / frame_height
        if height_ratio <= 0.0:
            return 80.0
        calculated = 3.0 / height_ratio
        return min(max(calculated, 0.5), 80.0)

    def get_distance_category(self, bbox, label, frame_height):
        height_ratio = (bbox[3] - bbox[1]) / frame_height
        if height_ratio > 0.50:
            return "very_close"
        elif height_ratio > 0.30:
            return "close"
        elif height_ratio > 0.15:
            return "medium"
        else:
            return "far"

    def track(self, detections, frame_height):
        self.frame_count += 1
        new_tracks = {}
        matched_detections = set()

        # 1. Match current detections with existing tracked objects
        for obj_id, tracked in self.tracked_objects.items():
            best_det_idx = -1
            best_iou = self.iou_threshold

            for idx, det in enumerate(detections):
                if idx in matched_detections:
                    continue
                if det["label"] == tracked["label"]:
                    iou = self.calculate_iou(tracked["bbox"], det["bbox"])
                    if iou > best_iou:
                        best_iou = iou
                        best_det_idx = idx

            if best_det_idx != -1:
                matched_detections.add(best_det_idx)
                det = detections[best_det_idx]
                
                # Check area growth streak
                curr_box = det["bbox"]
                prev_box = tracked["bbox"]
                curr_area = (curr_box[2] - curr_box[0]) * (curr_box[3] - curr_box[1])
                prev_area = (prev_box[2] - prev_box[0]) * (prev_box[3] - prev_box[1])

                if curr_area > prev_area * 1.04:
                    tracked["area_growth_streak"] += 1
                else:
                    tracked["area_growth_streak"] = 0

                tracked["bbox"] = curr_box
                tracked["confidence"] = det["confidence"]
                tracked["is_approaching"] = tracked["area_growth_streak"] >= 2
                tracked["distance"] = self.estimate_distance(curr_box, det["label"], frame_height)
                tracked["distance_category"] = self.get_distance_category(curr_box, det["label"], frame_height)
                tracked["last_seen"] = self.frame_count
                new_tracks[obj_id] = tracked
            else:
                # Keep object for a few frames if lost temporarily
                if self.frame_count - tracked["last_seen"] < self.max_lost_frames:
                    new_tracks[obj_id] = tracked

        # 2. Add unmatched detections as new tracks
        for idx, det in enumerate(detections):
            if idx in matched_detections:
                continue
            obj_id = f"veh_{self.frame_count}_{idx}"
            dist = self.estimate_distance(det["bbox"], det["label"], frame_height)
            cat = self.get_distance_category(det["bbox"], det["label"], frame_height)
            new_tracks[obj_id] = {
                "label": det["label"],
                "confidence": det["confidence"],
                "bbox": det["bbox"],
                "distance": dist,
                "distance_category": cat,
                "is_approaching": True,  # Default to approaching for warning safety
                "area_growth_streak": 0,
                "last_seen": self.frame_count
            }

        self.tracked_objects = new_tracks
        return self.tracked_objects


def evaluate_safety_verdict(tracked_objects):
    verdict = "SAFE"
    
    for obj_id, obj in tracked_objects.items():
        if obj["label"] == "pedestrian":
            continue

        category = obj["distance_category"]
        is_approaching = obj["is_approaching"]

        if category == "very_close" and is_approaching:
            # Rule 1: Very Close + Approaching = DANGER
            return "DANGER"
        elif category == "close" and is_approaching:
            # Rule 2: Close + Approaching = WARNING
            if verdict != "DANGER":
                verdict = "WARNING"
        elif category == "medium" and is_approaching:
            # Rule 3: Medium + Approaching = CAUTION
            if verdict != "DANGER" and verdict != "WARNING":
                verdict = "CAUTION"
                
    return verdict


def main():
    import os
    print("Initializing YOLOv8 Traffic Safety pipeline...")
    # Load model (can be yolov8n.pt or exported yolov8n_car.tflite)
    model = YOLO("yolov8n.pt")
    
    # Target COCO IDs mapped to domains of interest
    target_classes = {
        0: "pedestrian",
        1: "bicycle",
        2: "car",
        3: "motorcycle",
        5: "bus",
        7: "truck"
    }

    # Check if static image car.jpg is in the same directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    static_img_path = os.path.join(script_dir, "car.jpg")
    
    use_static = False
    if os.path.exists(static_img_path):
        print(f"Found static image: {static_img_path}. Processing as a single frame.")
        use_static = True

    tracker = PythonVehicleTracker()

    if use_static:
        frame = cv2.imread(static_img_path)
        if frame is None:
            print(f"Error: Could not read image {static_img_path}")
            return
        
        height, width, _ = frame.shape
        
        # Run inference
        results = model(frame, verbose=False)[0]
        detections = []

        # Parse current detections
        for box in results.boxes:
            class_id = int(box.cls[0].item())
            confidence = float(box.conf[0].item())
            
            if class_id in target_classes and confidence >= 0.35:
                xyxy = box.xyxy[0].tolist()  # [left, top, right, bottom]
                detections.append({
                    "label": target_classes[class_id],
                    "confidence": confidence,
                    "bbox": [int(xyxy[0]), int(xyxy[1]), int(xyxy[2]), int(xyxy[3])]
                })

        # Run Tracker & Safety calculations
        tracked_objects = tracker.track(detections, height)
        overall_verdict = evaluate_safety_verdict(tracked_objects)

        # Determine HUD Styles
        if overall_verdict == "DANGER":
            banner_color = (0, 0, 255)  # Red (BGR)
            banner_text = "WARNING! DO NOT CROSS"
            tts_msg = "Warning. Vehicle approaching. Do not cross."
        elif overall_verdict == "WARNING":
            banner_color = (0, 255, 255)  # Yellow (BGR)
            banner_text = "WARNING! VEHICLE DETECTED"
            tts_msg = "Please wait. Vehicle detected."
        elif overall_verdict == "CAUTION":
            banner_color = (0, 255, 255)  # Yellow (BGR)
            banner_text = "CAUTION! VEHICLE DETECTED"
            tts_msg = "Please be careful."
        else:
            banner_color = (0, 255, 0)  # Green (BGR)
            banner_text = "SAFE TO CROSS"
            tts_msg = "Safe to cross."

        # Draw Safety Banner Overlay at top
        cv2.rectangle(frame, (0, 0), (width, 80), banner_color, -1)
        cv2.putText(frame, banner_text, (int(width * 0.1), 50), 
                    cv2.FONT_HERSHEY_SIMPLEX, 1.2, (255, 255, 255), 3, cv2.LINE_AA)

        # Format and draw individual tracked targets
        frame_info_list = []
        for obj_id, obj in tracked_objects.items():
            bbox = obj["bbox"]
            label = obj["label"]
            conf = obj["confidence"]
            dist = obj["distance"]
            dist_cat = obj["distance_category"]
            is_approaching = obj["is_approaching"]

            # Determine individual warning style
            if dist_cat == "very_close" and is_approaching:
                box_color = (0, 0, 255)  # Red
                alert_level = "danger"
            elif dist_cat == "close" and is_approaching:
                box_color = (0, 255, 255)  # Yellow
                alert_level = "warning"
            elif dist_cat == "medium" and is_approaching:
                box_color = (0, 255, 255)  # Yellow
                alert_level = "caution"
            else:
                box_color = (0, 255, 0)  # Green
                alert_level = "safe"

            # Draw bounding box
            cv2.rectangle(frame, (bbox[0], bbox[1]), (bbox[2], bbox[3]), box_color, 2)
            
            # Draw corner brackets for high-tech HUD look
            bracket_len = int((bbox[2] - bbox[0]) * 0.15)
            # Top Left
            cv2.line(frame, (bbox[0], bbox[1]), (bbox[0] + bracket_len, bbox[1]), box_color, 5)
            cv2.line(frame, (bbox[0], bbox[1]), (bbox[0], bbox[1] + bracket_len), box_color, 5)
            # Top Right
            cv2.line(frame, (bbox[2], bbox[1]), (bbox[2] - bracket_len, bbox[1]), box_color, 5)
            cv2.line(frame, (bbox[2], bbox[1]), (bbox[2], bbox[1] + bracket_len), box_color, 5)
            # Bottom Left
            cv2.line(frame, (bbox[0], bbox[3]), (bbox[0] + bracket_len, bbox[3]), box_color, 5)
            cv2.line(frame, (bbox[0], bbox[3]), (bbox[0], bbox[3] - bracket_len), box_color, 5)
            # Bottom Right
            cv2.line(frame, (bbox[2], bbox[3]), (bbox[2] - bracket_len, bbox[3]), box_color, 5)
            cv2.line(frame, (bbox[2], bbox[3]), (bbox[2], bbox[3] - bracket_len), box_color, 5)

            label_str = f"{label.upper()} {int(conf * 100)}% | Distance: {dist:.0f} m | Status: {alert_level.upper()}"
            cv2.putText(frame, label_str, (bbox[0] + 5, bbox[1] - 10 if bbox[1] - 10 > 20 else bbox[1] + 20), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_AA)

            # Build formatted JSON target object printout
            target_info = {
                "label": label,
                "confidence": round(conf, 2),
                "distance": dist_cat,
                "isApproaching": is_approaching,
                "alert": alert_level,
                "color": "red" if alert_level == "danger" else ("yellow" if alert_level in ["warning", "caution"] else "green"),
                "voice": tts_msg
            }
            frame_info_list.append(target_info)

        # Print JSON detection payload to terminal
        if frame_info_list:
            print(f"[{time.strftime('%H:%M:%S')}] Frame Detections: {json.dumps(frame_info_list)}")
            print(f"Safety Verdict: {overall_verdict} | TTS Voice Warning: \"{tts_msg}\"")
        else:
            print("No detections found in static image.")

        # TTS voice alerts using pyttsx3 if loaded
        if tts_engine:
            try:
                tts_engine.say(tts_msg)
                tts_engine.runAndWait()
            except Exception as e:
                print(f"TTS Error: {e}")

        # Save the output image
        output_path = os.path.join(script_dir, "output_car.jpg")
        cv2.imwrite(output_path, frame)
        print(f"HUD image saved successfully to: {output_path}")

        # Render preview window if graphical display is supported
        try:
            cv2.imshow("AI Crossing Safety HUD - Python Demo", frame)
            print("Showing image preview. Exiting in 1 second...")
            cv2.waitKey(1000)
            cv2.destroyAllWindows()
        except Exception:
            print("Headless environment or no display device. Skipped GUI window.")
        return

    # Open webcam or video file stream if no static image is found
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Error: Could not open camera/video feed.")
        return

    print("Real-Time AI Pedestrian Safety Assistant Active. Press 'q' to exit.")

    while True:
      ret, frame = cap.read()
      if not ret:
          break

      height, width, _ = frame.shape
      
      # Run inference
      results = model(frame, verbose=False)[0]
      detections = []

      # Parse current detections
      for box in results.boxes:
          class_id = int(box.cls[0].item())
          confidence = float(box.conf[0].item())
          
          if class_id in target_classes and confidence >= 0.35:
              xyxy = box.xyxy[0].tolist()  # [left, top, right, bottom]
              detections.append({
                  "label": target_classes[class_id],
                  "confidence": confidence,
                  "bbox": [int(xyxy[0]), int(xyxy[1]), int(xyxy[2]), int(xyxy[3])]
              })

      # Run Tracker & Safety calculations
      tracked_objects = tracker.track(detections, height)
      overall_verdict = evaluate_safety_verdict(tracked_objects)

      # Determine HUD Styles
      if overall_verdict == "DANGER":
          banner_color = (0, 0, 255)  # Red (BGR)
          banner_text = "WARNING! DO NOT CROSS"
          tts_msg = "Warning. Vehicle approaching. Do not cross."
      elif overall_verdict == "WARNING":
          banner_color = (0, 255, 255)  # Yellow (BGR)
          banner_text = "WARNING! VEHICLE DETECTED"
          tts_msg = "Please wait. Vehicle detected."
      elif overall_verdict == "CAUTION":
          banner_color = (0, 255, 255)  # Yellow (BGR)
          banner_text = "CAUTION! VEHICLE DETECTED"
          tts_msg = "Please be careful."
      else:
          banner_color = (0, 255, 0)  # Green (BGR)
          banner_text = "SAFE TO CROSS"
          tts_msg = "Safe to cross."

      # Draw Safety Banner Overlay at top
      cv2.rectangle(frame, (0, 0), (width, 80), banner_color, -1)
      cv2.putText(frame, banner_text, (int(width * 0.1), 50), 
                  cv2.FONT_HERSHEY_SIMPLEX, 1.2, (255, 255, 255), 3, cv2.LINE_AA)

      # Format and draw individual tracked targets
      frame_info_list = []
      for obj_id, obj in tracked_objects.items():
          # Calculate coordinates
          bbox = obj["bbox"]
          label = obj["label"]
          conf = obj["confidence"]
          dist = obj["distance"]
          dist_cat = obj["distance_category"]
          is_approaching = obj["is_approaching"]

          # Determine individual warning style
          if dist_cat == "very_close" and is_approaching:
              box_color = (0, 0, 255)  # Red
              alert_level = "danger"
          elif dist_cat == "close" and is_approaching:
              box_color = (0, 255, 255)  # Yellow
              alert_level = "warning"
          elif dist_cat == "medium" and is_approaching:
              box_color = (0, 255, 255)  # Yellow
              alert_level = "caution"
          else:
              box_color = (0, 255, 0)  # Green
              alert_level = "safe"

          # Draw neon bounding box
          cv2.rectangle(frame, (bbox[0], bbox[1]), (bbox[2], bbox[3]), box_color, 2)
          
          # Draw corner brackets for high-tech HUD look
          bracket_len = int((bbox[2] - bbox[0]) * 0.15)
          # Top Left
          cv2.line(frame, (bbox[0], bbox[1]), (bbox[0] + bracket_len, bbox[1]), box_color, 5)
          cv2.line(frame, (bbox[0], bbox[1]), (bbox[0], bbox[1] + bracket_len), box_color, 5)
          # Top Right
          cv2.line(frame, (bbox[2], bbox[1]), (bbox[2] - bracket_len, bbox[1]), box_color, 5)
          cv2.line(frame, (bbox[2], bbox[1]), (bbox[2], bbox[1] + bracket_len), box_color, 5)
          # Bottom Left
          cv2.line(frame, (bbox[0], bbox[3]), (bbox[0] + bracket_len, bbox[3]), box_color, 5)
          cv2.line(frame, (bbox[0], bbox[3]), (bbox[0], bbox[3] - bracket_len), box_color, 5)
          # Bottom Right
          cv2.line(frame, (bbox[2], bbox[3]), (bbox[2] - bracket_len, bbox[3]), box_color, 5)
          cv2.line(frame, (bbox[2], bbox[3]), (bbox[2], bbox[3] - bracket_len), box_color, 5)

          label_str = f"{label.upper()} {int(conf * 100)}% | Distance: {dist:.0f} m | Status: {alert_level.upper()}"
          cv2.putText(frame, label_str, (bbox[0] + 5, bbox[1] - 10 if bbox[1] - 10 > 20 else bbox[1] + 20), 
                      cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_AA)

          # Build formatted JSON target object printout
          target_info = {
              "label": label,
              "confidence": round(conf, 2),
              "distance": dist_cat,
              "isApproaching": is_approaching,
              "alert": alert_level,
              "color": "red" if alert_level == "danger" else ("yellow" if alert_level in ["warning", "caution"] else "green"),
              "voice": tts_msg
          }
          frame_info_list.append(target_info)

      # Print JSON detection payload to terminal
      if frame_info_list:
          print(f"[{time.strftime('%H:%M:%S')}] Frame Detections: {json.dumps(frame_info_list)}")
          print(f"Safety Verdict: {overall_verdict} | TTS Voice Warning: \"{tts_msg}\"")

      # TTS voice alerts using pyttsx3 if loaded
      if tts_engine and frame_info_list:
          try:
              tts_engine.say(tts_msg)
              tts_engine.runAndWait()
          except Exception:
              pass

      # Render preview window
      try:
          cv2.imshow("AI Crossing Safety HUD - Python Demo", frame)
      except Exception:
          pass

      # Check for exit key
      if cv2.waitKey(1) & 0xFF == ord('q'):
          break

    cap.release()
    try:
        cv2.destroyAllWindows()
    except Exception:
        pass

if __name__ == "__main__":
    main()
