import 'package:flutter/material.dart';

enum DistanceCategory {
  VERY_CLOSE, // Extremely dangerous
  CLOSE,      // Dangerous if approaching
  MEDIUM,     // Caution area
  FAR         // Safe
}

class DetectedObject {
  final String label;
  final double confidence;
  
  // Normalized coordinates [0.0, 1.0] for drawing the box: [left, top, width, height]
  final Rect boundingBox;
  
  final double estimatedDistance; // in meters
  final bool isApproaching;
  final DistanceCategory distanceCategory;
  
  DetectedObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.estimatedDistance,
    required this.isApproaching,
    DistanceCategory? distanceCategory,
  }) : this.distanceCategory = distanceCategory ?? _calculateCategory(estimatedDistance, label, boundingBox);

  static DistanceCategory _calculateCategory(double distance, String label, Rect box) {
    if (label.toLowerCase() == 'car') {
      final heightRatio = box.height;
      if (heightRatio > 0.48) return DistanceCategory.VERY_CLOSE;
      if (heightRatio > 0.28) return DistanceCategory.CLOSE;
      if (heightRatio > 0.12) return DistanceCategory.MEDIUM;
      return DistanceCategory.FAR;
    } else {
      if (distance < 5.0) return DistanceCategory.VERY_CLOSE;
      if (distance < 15.0) return DistanceCategory.CLOSE;
      if (distance < 25.0) return DistanceCategory.MEDIUM;
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
      'distanceCategory': _categoryToString(distanceCategory),
    };
  }

  static String _categoryToString(DistanceCategory cat) {
    switch (cat) {
      case DistanceCategory.VERY_CLOSE: return 'very_close';
      case DistanceCategory.CLOSE: return 'close';
      case DistanceCategory.MEDIUM: return 'medium';
      case DistanceCategory.FAR: return 'far';
    }
  }

  // Factory constructor to decode from native JSON channel results
  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    final boxList = List<double>.from(json['boundingBox']);
    final box = Rect.fromLTWH(boxList[0], boxList[1], boxList[2], boxList[3]);
    final categoryStr = json['distanceCategory'] as String?;
    DistanceCategory? parsedCategory;
    
    if (categoryStr != null) {
      switch (categoryStr) {
        case 'very_close':
          parsedCategory = DistanceCategory.VERY_CLOSE;
          break;
        case 'close':
          parsedCategory = DistanceCategory.CLOSE;
          break;
        case 'medium':
          parsedCategory = DistanceCategory.MEDIUM;
          break;
        case 'far':
          parsedCategory = DistanceCategory.FAR;
          break;
      }
    }
    
    return DetectedObject(
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      boundingBox: box,
      estimatedDistance: (json['estimatedDistance'] as num).toDouble(),
      isApproaching: json['isApproaching'] as bool,
      distanceCategory: parsedCategory,
    );
  }
}
