import 'package:flutter/material.dart';

enum DistanceCategory {
  VERY_CLOSE, // Extremely dangerous
  CLOSE,      // Dangerous if approaching
  FAR         // Safe
}

class DetectedObject {
  final String label;
  final double confidence;
  
  // Normalized coordinates [0.0, 1.0] for drawing the box: [left, top, width, height]
  final Rect boundingBox;
  
  final double estimatedDistance; // in meters
  final bool isApproaching;
  
  DetectedObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.estimatedDistance,
    required this.isApproaching,
  });

  DistanceCategory get distanceCategory {
    if (estimatedDistance < 5.0) {
      return DistanceCategory.VERY_CLOSE;
    } else if (estimatedDistance < 15.0) {
      return DistanceCategory.CLOSE;
    } else {
      return DistanceCategory.FAR;
    }
  }

  // Helper to convert normalized coordinate representation into JSON
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'confidence': confidence,
      'boundingBox': [boundingBox.left, boundingBox.top, boundingBox.width, boundingBox.height],
      'estimatedDistance': estimatedDistance,
      'isApproaching': isApproaching,
    };
  }

  // Factory constructor to decode from native JSON channel results
  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    final boxList = List<double>.from(json['boundingBox']);
    return DetectedObject(
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      boundingBox: Rect.fromLTWH(boxList[0], boxList[1], boxList[2], boxList[3]),
      estimatedDistance: (json['estimatedDistance'] as num).toDouble(),
      isApproaching: json['isApproaching'] as bool,
    );
  }
}
