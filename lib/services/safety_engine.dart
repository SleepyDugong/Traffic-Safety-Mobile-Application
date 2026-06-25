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

  /// Evaluates safety and returns a verdict: NOT_SAFE, SAFE_STOPPED, or SAFE_NO_VEHICLES.
  String evaluateSafety(List<DetectedObject> detections) {
    // Filter to targets that are vehicles (Car, Bus, Truck, Motorcycle, Bicycle)
    // COCO vehicle classes: car, bus, truck, motorcycle, bicycle, bike
    final vehicles = detections.where((d) {
      final label = d.label.toLowerCase();
      return label == 'car' ||
             label == 'bus' ||
             label == 'truck' ||
             label == 'motorcycle' ||
             label == 'bicycle' ||
             label == 'bike';
    }).toList();

    if (vehicles.isEmpty) {
      _currentVerdict = "SAFE_NO_VEHICLES";
      notifyListeners();
      return _currentVerdict;
    }

    // Rule 1: If any vehicle is approaching -> NOT_SAFE
    final hasApproaching = vehicles.any((v) => v.isApproaching);

    if (hasApproaching) {
      _currentVerdict = "NOT_SAFE";
    } else {
      // Rule 2: If all vehicles are stopped (or receding, meaning none are approaching) -> SAFE_STOPPED
      _currentVerdict = "SAFE_STOPPED";
    }

    notifyListeners();
    return _currentVerdict;
  }
}
