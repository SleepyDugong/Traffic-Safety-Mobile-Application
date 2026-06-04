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

  /// Evaluates safety and returns a verdict.
  /// If any vehicle is closer than 5 meters, OR
  /// if a vehicle is between 5 and threshold meters AND is approaching,
  /// then it returns DANGER. Otherwise it is SAFE.
  String evaluateSafety(List<DetectedObject> detections) {
    if (detections.isEmpty) {
      _currentVerdict = "SAFE";
      notifyListeners();
      return _currentVerdict;
    }

    bool hasDanger = false;
    for (var detection in detections) {
      // Skip non-vehicle detections for crossing verdicts (like other pedestrians)
      if (detection.label.toLowerCase() == 'pedestrian') {
        continue;
      }

      final distance = detection.estimatedDistance;
      final isApproaching = detection.isApproaching;

      if (distance < 5.0) {
        // Cars under 5m are immediately dangerous
        hasDanger = true;
        break;
      } else if (distance < _dangerThresholdDistance && isApproaching) {
        // Cars within threshold moving towards the pedestrian are dangerous
        hasDanger = true;
        break;
      }
    }

    _currentVerdict = hasDanger ? "DANGER" : "SAFE";
    notifyListeners();
    return _currentVerdict;
  }
}
