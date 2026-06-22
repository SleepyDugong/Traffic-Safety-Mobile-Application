import 'package:flutter/material.dart';
import '../models/detected_object.dart';

class SafetyEngine with ChangeNotifier {
  String _currentVerdict = "SAFE"; // SAFE or DANGER
  double _dangerThresholdDistance = 15.0; // In meters
  
  String get currentVerdict => _currentVerdict;
  double get dangerThresholdDistance => _dangerThresholdDistance;

  void updateDangerThreshold(double value) {
    _dangerThresholdDistance = value;
    notifyListeners();
  }

  /// Evaluates safety and returns a verdict: DANGER, CAUTION, or SAFE.
  String evaluateSafety(List<DetectedObject> detections) {
    if (detections.isEmpty) {
      _currentVerdict = "SAFE";
      notifyListeners();
      return _currentVerdict;
    }

    String verdict = "SAFE";

    for (var detection in detections) {
      // Skip non-vehicle detections (like other pedestrians)
      if (detection.label.toLowerCase() == 'pedestrian') {
        continue;
      }

      final category = detection.distanceCategory;
      final isApproaching = detection.isApproaching;

      // Evaluate safety rules:
      if (category == DistanceCategory.VERY_CLOSE) {
        // Rule 1: very_close vehicles trigger DANGER immediately (immediate hazard)
        verdict = "DANGER";
        break; // DANGER is the highest severity, stop checks
      } else if (category == DistanceCategory.CLOSE && isApproaching) {
        // Rule 2: close approaching vehicles trigger DANGER
        verdict = "DANGER";
        break; // DANGER is the highest severity
      } else if (category == DistanceCategory.MEDIUM && isApproaching) {
        // Rule 3: medium approaching vehicles trigger CAUTION (yellow warning)
        // If a subsequent detection is dangerous, it will upgrade this to DANGER.
        if (verdict != "DANGER") {
          verdict = "CAUTION";
        }
      }
      // Rule 4: receding vehicles (isApproaching == false) or distant vehicles leave status as SAFE (unless other checks apply)
    }

    _currentVerdict = verdict;
    notifyListeners();
    return _currentVerdict;
  }
}
