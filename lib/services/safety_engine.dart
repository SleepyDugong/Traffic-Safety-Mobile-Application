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

  /// Evaluates safety and returns a verdict: DANGER, WARNING, CAUTION, or SAFE.
  String evaluateSafety(List<DetectedObject> detections) {
    if (detections.isEmpty) {
      _currentVerdict = "SAFE";
      notifyListeners();
      return _currentVerdict;
    }

    String verdict = "SAFE";

    for (var detection in detections) {
      final normLabel = detection.label.toLowerCase();
      // Skip non-vehicle detections (like other pedestrians/persons)
      if (normLabel == 'pedestrian' || normLabel == 'person') {
        continue;
      }

      final category = detection.distanceCategory;
      final isApproaching = detection.isApproaching;

      // Evaluate safety rules:
      if (category == DistanceCategory.VERY_CLOSE && isApproaching) {
        // Rule 1: Very Close + Approaching = DANGER
        verdict = "DANGER";
        break; // DANGER is the highest severity, stop checks
      } else if (category == DistanceCategory.CLOSE && isApproaching) {
        // Rule 2: Close + Approaching = WARNING
        if (verdict != "DANGER") {
          verdict = "WARNING";
        }
      } else if (category == DistanceCategory.MEDIUM && isApproaching) {
        // Rule 3: Medium + Approaching = CAUTION
        if (verdict != "DANGER" && verdict != "WARNING") {
          verdict = "CAUTION";
        }
      }
      // Rule 4: Far + Moving Away = SAFE (leaves status as SAFE unless other checks apply)
    }

    _currentVerdict = verdict;
    notifyListeners();
    return _currentVerdict;
  }
}
