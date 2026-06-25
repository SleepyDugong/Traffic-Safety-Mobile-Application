import 'package:flutter/material.dart';
import '../models/detected_object.dart';

class DetectionOverlay extends StatelessWidget {
  final List<DetectedObject> detections;

  const DetectionOverlay({
    Key? key,
    required this.detections,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _DetectionPainter(detections: detections),
      ),
    );
  }
}

class _DetectionPainter extends CustomPainter {
  final List<DetectedObject> detections;

  _DetectionPainter({required this.detections});

  @override
  void paint(Canvas canvas, Size size) {
    for (var detection in detections) {
      final rect = Rect.fromLTWH(
        detection.boundingBox.left * size.width,
        detection.boundingBox.top * size.height,
        detection.boundingBox.width * size.width,
        detection.boundingBox.height * size.height,
      );

      // Dynamic color logic based on safety prompt rules
      Color boxColor = Colors.green;
      final labelLower = detection.label.toLowerCase();
      final isVehicle = labelLower == 'car' ||
                        labelLower == 'bus' ||
                        labelLower == 'truck' ||
                        labelLower == 'motorcycle' ||
                        labelLower == 'bicycle' ||
                        labelLower == 'bike';

      if (isVehicle) {
        if (detection.isApproaching) {
          if (detection.distanceCategory == DistanceCategory.VERY_CLOSE ||
              detection.distanceCategory == DistanceCategory.CLOSE) {
            boxColor = Colors.red;
          } else if (detection.distanceCategory == DistanceCategory.MEDIUM) {
            boxColor = Colors.yellow;
          } else {
            boxColor = Colors.green;
          }
        } else {
          boxColor = Colors.green; // stopped or moving away
        }
      } else {
        // Pedestrians / Persons default to green (safe)
        boxColor = Colors.green;
      }

      final paint = Paint()
        ..color = boxColor
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      // Draw sharp square box
      canvas.drawRect(rect, paint);

      // Configure text span
      final textSpan = TextSpan(
        text: " ${detection.label.toUpperCase()} ${(detection.confidence * 100).toStringAsFixed(0)}% • ${detection.estimatedDistance.toStringAsFixed(1)}m ${detection.isApproaching ? '▲' : '▼'} ",
        style: TextStyle(
          color: boxColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Position the label container above the top boundary of the box
      double labelY = rect.top - textPainter.height - 4;
      if (labelY < 0) {
        labelY = rect.top + 4;
      }

      // Draw solid black background rectangle for high contrast/readability
      final bgRect = Rect.fromLTWH(
        rect.left,
        labelY - 2,
        textPainter.width,
        textPainter.height + 4,
      );
      final bgPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;

      canvas.drawRect(bgRect, bgPaint);

      // Draw text label over the black background
      textPainter.paint(
        canvas,
        Offset(rect.left, labelY),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
