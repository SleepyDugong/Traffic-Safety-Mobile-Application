import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/detected_object.dart';

enum AppRunMode {
  LIVE_CAMERA,
  SIMULATION
}

class DetectionService with ChangeNotifier {
  static const MethodChannel _platformChannel = MethodChannel('com.trafficsafety.app/yolo');
  
  AppRunMode _runMode = AppRunMode.LIVE_CAMERA;
  bool _isDetecting = false;
  List<DetectedObject> _currentDetections = [];
  
  // Timer for simulating frames
  Timer? _simulationTimer;
  double _simTime = 0.0;
  String _simulationScenario = "street_busy"; // "street_clear" or "street_busy"

  AppRunMode get runMode => _runMode;
  bool get isDetecting => _isDetecting;
  List<DetectedObject> get currentDetections => _currentDetections;
  String get simulationScenario => _simulationScenario;

  void setRunMode(AppRunMode mode) {
    _runMode = mode;
    if (_isDetecting) {
      // Restart with the new mode
      stopDetection();
      startDetection();
    }
    notifyListeners();
  }

  void setSimulationScenario(String scenario) {
    _simulationScenario = scenario;
    notifyListeners();
  }

  void startDetection() {
    if (_isDetecting) return;
    _isDetecting = true;
    notifyListeners();

    if (_runMode == AppRunMode.SIMULATION) {
      _startSimulationLoop();
    } else {
      _startNativeCameraLoop();
    }
  }

  void stopDetection() {
    if (!_isDetecting) return;
    _isDetecting = false;
    _simulationTimer?.cancel();
    _currentDetections = [];
    notifyListeners();
  }

  void _startSimulationLoop() {
    _simTime = 0.0;
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _simTime += 0.1;
      _generateSimulatedFrame();
    });
  }

  void _startNativeCameraLoop() async {
    // In native camera loop, we send trigger requests to MainActivity.kt platform channel.
    // In actual implementation, Android Camera2 API triggers frame capture, 
    // FrameProcessor.kt processes the image via OpenCV, and YoloDetector.kt runs TFLite.
    // It returns results asynchronously. Here we set up a loop that polls native results.
    while (_isDetecting && _runMode == AppRunMode.LIVE_CAMERA) {
      try {
        final List<dynamic> results = await _platformChannel.invokeMethod('getLatestDetections');
        _currentDetections = results.map((e) {
          final map = Map<String, dynamic>.from(e);
          return DetectedObject.fromJson(map);
        }).toList();
        notifyListeners();
      } on PlatformException catch (e) {
        debugPrint("Native Platform Channel Error: ${e.message}");
        // Fallback to simulation if native channel fails (e.g. running on Windows)
        _generateSimulatedFrame();
      }
      await Future.delayed(const Duration(milliseconds: 100)); // Poll at 10 FPS
    }
  }

  Future<void> processFrame({
    required int width,
    required int height,
    required Uint8List yBytes,
    required Uint8List uBytes,
    required Uint8List vBytes,
    required int yRowStride,
    required int uRowStride,
    required int vRowStride,
    required int uPixelStride,
    required int vPixelStride,
    int sensorOrientation = 90,
  }) async {
    if (!_isDetecting || _runMode != AppRunMode.LIVE_CAMERA) return;
    try {
      final List<dynamic> results = await _platformChannel.invokeMethod('processFrame', {
        'width': width,
        'height': height,
        'y': yBytes,
        'u': uBytes,
        'v': vBytes,
        'yRowStride': yRowStride,
        'uRowStride': uRowStride,
        'vRowStride': vRowStride,
        'uPixelStride': uPixelStride,
        'vPixelStride': vPixelStride,
        'sensorOrientation': sensorOrientation,
      });
      _currentDetections = results.map((e) {
        final map = Map<String, dynamic>.from(e);
        return DetectedObject.fromJson(map);
      }).toList();
      notifyListeners();
    } on PlatformException catch (e) {
      debugPrint("Native Platform Channel processFrame Error: ${e.message}");
    }
  }

  /// Generates mock cars, bikes, and trucks that move on screen
  void _generateSimulatedFrame() {
    final List<DetectedObject> detections = [];

    if (_simulationScenario == "street_busy") {
      // Scenario: Busy Street. Vehicles are approaching the user.
      
      // Car 1: Approaching in the center lane
      // Starts far away and gets closer. Loop every 8 seconds.
      double car1Progress = (_simTime % 8.0) / 8.0; 
      double car1Distance = 60.0 - (car1Progress * 58.0); // starts at 60m, stops at 2m
      if (car1Distance > 1.5) {
        // Compute bounding box coordinates [left, top, width, height]
        // Center x is 0.35. Box width/height scales up as it gets closer
        double scale = 1.0 / (car1Distance / 6.0); // grows larger as distance gets smaller
        scale = scale.clamp(0.05, 0.7);
        
        detections.add(DetectedObject(
          label: "Car",
          confidence: 0.94,
          boundingBox: Rect.fromLTWH(
            0.5 - (scale / 2), // centered horizontal
            0.6 - (scale / 3), // vertical position
            scale,
            scale,
          ),
          estimatedDistance: car1Distance,
          isApproaching: true,
        ));
      }

      // Motorcycle 1: Faster vehicle approaching. Loop every 5 seconds, offset by 3s.
      double motoProgress = ((_simTime + 3.0) % 5.0) / 5.0;
      double motoDistance = 70.0 - (motoProgress * 68.0);
      if (motoDistance > 1.5) {
        double scale = 0.6 / (motoDistance / 6.0);
        scale = scale.clamp(0.03, 0.4);
        detections.add(DetectedObject(
          label: "Motorcycle",
          confidence: 0.88,
          boundingBox: Rect.fromLTWH(
            0.2 - (scale / 2), // approaching on the left side
            0.55 - (scale / 3),
            scale,
            scale * 1.2,
          ),
          estimatedDistance: motoDistance,
          isApproaching: true,
        ));
      }

      // Truck 1: A slow truck approaching. Loop every 12 seconds.
      double truckProgress = ((_simTime + 6.0) % 12.0) / 12.0;
      double truckDistance = 50.0 - (truckProgress * 45.0);
      if (truckDistance > 3.0) {
        double scale = 1.3 / (truckDistance / 6.0);
        scale = scale.clamp(0.08, 0.8);
        detections.add(DetectedObject(
          label: "Truck",
          confidence: 0.91,
          boundingBox: Rect.fromLTWH(
            0.75 - (scale / 2), // approaching on the right side
            0.5 - (scale / 4),
            scale,
            scale * 1.3,
          ),
          estimatedDistance: truckDistance,
          isApproaching: true,
        ));
      }
    } else {
      // Scenario: Clear Street. Vehicles are far away or moving away.
      
      // Car 2: A car moving away (receding). Loop every 10 seconds.
      double car2Progress = (_simTime % 10.0) / 10.0;
      double car2Distance = 20.0 + (car2Progress * 60.0); // starts at 20m, goes to 80m
      double scale = 1.0 / (car2Distance / 6.0);
      scale = scale.clamp(0.02, 0.25);
      
      detections.add(DetectedObject(
        label: "Car",
        confidence: 0.85,
        boundingBox: Rect.fromLTWH(
          0.3,
          0.5,
          scale,
          scale,
        ),
        estimatedDistance: car2Distance,
        isApproaching: false, // Receding
      ));

      // Pedestrian: Another pedestrian walking safely on the sidewalk
      double pedProgress = (_simTime % 15.0) / 15.0;
      double pedX = 0.85 - (pedProgress * 0.3); // walking left on the sidewalk
      detections.add(DetectedObject(
        label: "Pedestrian",
        confidence: 0.96,
        boundingBox: const Rect.fromLTWH(0.8, 0.45, 0.1, 0.25),
        estimatedDistance: 12.0,
        isApproaching: false,
      ));
    }

    _currentDetections = detections;
    notifyListeners();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }
}
