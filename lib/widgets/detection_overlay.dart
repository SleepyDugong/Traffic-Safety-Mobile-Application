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

      Color boxColor;
      Color bracketColor;

      final category = detection.distanceCategory;
      final isApproaching = detection.isApproaching;

      if (category == DistanceCategory.VERY_CLOSE || 
          (category == DistanceCategory.CLOSE && isApproaching)) {
        boxColor = const Color(0xFFFF3B30); // Red
        bracketColor = const Color(0xFFFF453A); // Neon Red
      } else if (category == DistanceCategory.MEDIUM && isApproaching) {
        boxColor = const Color(0xFFFF9F0A); // Yellow/Amber
        bracketColor = const Color(0xFFFFB30A); // Neon Yellow
      } else {
        boxColor = const Color(0xFF30D158); // Green
        bracketColor = const Color(0xFF34C759); // Neon Green
      }

      // Neon paint for bounding boxes
      final boxPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      // Draw bounding box
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        boxPaint,
      );

      // Draw corner brackets for high-tech HUD look
      final bracketPaint = Paint()
        ..color = bracketColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0;

      final double bracketLength = (rect.width * 0.2).clamp(10.0, 30.0);

      // Top Left Corner
      canvas.drawLine(rect.topLeft, rect.topLeft + Offset(bracketLength, 0), bracketPaint);
      canvas.drawLine(rect.topLeft, rect.topLeft + Offset(0, bracketLength), bracketPaint);
      
      // Top Right Corner
      canvas.drawLine(rect.topRight, rect.topRight + Offset(-bracketLength, 0), bracketPaint);
      canvas.drawLine(rect.topRight, rect.topRight + Offset(0, bracketLength), bracketPaint);
      
      // Bottom Left Corner
      canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(bracketLength, 0), bracketPaint);
      canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(0, -bracketLength), bracketPaint);
      
      // Bottom Right Corner
      canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(-bracketLength, 0), bracketPaint);
      canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(0, -bracketLength), bracketPaint);

      // Label text configuration
      final textSpan = TextSpan(
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          backgroundColor: boxColor.withOpacity(0.85),
        ),
        text: " ${detection.label.toUpperCase()} • ${detection.estimatedDistance.toStringAsFixed(1)}m ${detection.isApproaching ? '▲' : '▼'} ",
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Position the label slightly above the bounding box, or inside if too close to the top
      double labelY = rect.top - textPainter.height - 4;
      if (labelY < 0) {
        labelY = rect.top + 4;
      }
      
      textPainter.paint(
        canvas,
        Offset(rect.left + 4, labelY),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
