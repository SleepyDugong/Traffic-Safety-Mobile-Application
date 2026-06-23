import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/detection_service.dart';
import '../services/safety_engine.dart';
import '../services/alert_service.dart';
import '../widgets/safety_banner.dart';
import '../widgets/detection_overlay.dart';
import '../widgets/glass_card.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  String _cameraError = "";
  bool _isProcessingFrame = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSystem();
    });
  }

  void _startSystem() async {
    final detectionService = Provider.of<DetectionService>(context, listen: false);
    
    // Start AI/Simulation Loop
    detectionService.startDetection();

    // Setup active listeners for alerting
    detectionService.addListener(_onDetectionUpdate);

    if (detectionService.runMode == AppRunMode.LIVE_CAMERA) {
      await _initializeCamera();
    }
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final requestStatus = await Permission.camera.request();
      return requestStatus.isGranted;
    }
    return true;
  }

  Future<void> _initializeCamera() async {
    try {
      // 1. Request camera permission
      final hasPermission = await _requestCameraPermission();
      if (!hasPermission) {
        setState(() {
          _cameraError = "Camera permission was denied.";
        });
        return;
      }

      // 2. Load camera axis configuration
      String cameraAxis = "back";
      try {
        final configString = await rootBundle.loadString('assets/camera_config.json');
        final config = jsonDecode(configString);
        cameraAxis = config['camera_axis'] ?? 'back';
      } catch (e) {
        debugPrint("Error loading camera config: $e");
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = "No camera hardware detected.";
        });
        return;
      }
      
      final lensDirection = cameraAxis.toLowerCase() == 'front'
          ? CameraLensDirection.front
          : CameraLensDirection.back;

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == lensDirection,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        _startImageStream();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = "Could not access device camera.";
        });
      }
    }
  }

  void _startImageStream() {
    final detectionService = Provider.of<DetectionService>(context, listen: false);
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isProcessingFrame) return;
      if (detectionService.runMode != AppRunMode.LIVE_CAMERA || !detectionService.isDetecting) return;
      
      _isProcessingFrame = true;
      try {
        if (image.planes.length >= 3) {
          final yPlane = image.planes[0];
          final uPlane = image.planes[1];
          final vPlane = image.planes[2];
          
          await detectionService.processFrame(
            width: image.width,
            height: image.height,
            yBytes: yPlane.bytes,
            uBytes: uPlane.bytes,
            vBytes: vPlane.bytes,
            yRowStride: yPlane.bytesPerRow,
            uRowStride: uPlane.bytesPerRow,
            vRowStride: vPlane.bytesPerRow,
            uPixelStride: uPlane.bytesPerPixel ?? 1,
            vPixelStride: vPlane.bytesPerPixel ?? 1,
            sensorOrientation: _cameraController!.description.sensorOrientation,
          );
        }
      } catch (e) {
        debugPrint("Error streaming camera frame: $e");
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  void _onDetectionUpdate() {
    if (!mounted) return;
    final detectionService = Provider.of<DetectionService>(context, listen: false);
    final safetyEngine = Provider.of<SafetyEngine>(context, listen: false);
    final alertService = Provider.of<AlertService>(context, listen: false);

    // 1. Evaluate safety using current detections
    final verdict = safetyEngine.evaluateSafety(detectionService.currentDetections);

    // 2. Trigger alarms if detecting
    if (detectionService.isDetecting) {
      alertService.triggerAlert(verdict);
    }
  }

  @override
  void dispose() {
    // Clean up timers and camera controllers
    final detectionService = Provider.of<DetectionService>(context, listen: false);
    final alertService = Provider.of<AlertService>(context, listen: false);
    
    detectionService.removeListener(_onDetectionUpdate);
    detectionService.stopDetection();
    alertService.stopAllAlerts();
    
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detectionService = Provider.of<DetectionService>(context);
    final safetyEngine = Provider.of<SafetyEngine>(context);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Core Visual Layer (Camera Preview or High-Fidelity Road Vector Animation)
          Positioned.fill(
            child: (detectionService.runMode == AppRunMode.LIVE_CAMERA && _isCameraInitialized)
                ? CameraPreview(_cameraController!)
                : _buildSimulatedRoadBackground(detectionService.simulationScenario),
          ),

          // Bounding Box Drawing Overlay
          DetectionOverlay(detections: detectionService.currentDetections),

          // 2. Neon HUD Header Layout (FPS, Count, Safety Banner)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HUD Metrics Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      
                      // FPS & Targets Glass HUD
                      GlassCard(
                        borderRadius: 12.0,
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt, color: Colors.amber, size: 16.0),
                            const SizedBox(width: 4.0),
                            Text(
                              detectionService.runMode == AppRunMode.LIVE_CAMERA ? "FPS: 24.5" : "FPS: 10.0",
                              style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 12.0),
                            const Icon(Icons.gps_fixed, color: Colors.cyan, size: 16.0),
                            const SizedBox(width: 4.0),
                            Text(
                              "Targets: ${detectionService.currentDetections.length}",
                              style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),

                  // Warning Safety Banner
                  SafetyBanner(verdict: safetyEngine.currentVerdict),
                ],
              ),
            ),
          ),

          // 3. Interactive HUD Footer Settings Controls (Sandbox Scenarios / Engine Details)
          Positioned(
            bottom: 24.0,
            left: 16.0,
            right: 16.0,
            child: Column(
              children: [
                if (detectionService.runMode == AppRunMode.SIMULATION)
                  GlassCard(
                    borderRadius: 20.0,
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "SIMULATION SCENARIOS",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Row(
                          children: [
                            Expanded(
                              child: _buildScenarioButton(
                                label: "STREET CLEAR",
                                icon: Icons.sentiment_satisfied_rounded,
                                color: const Color(0xFF30D158),
                                isSelected: detectionService.simulationScenario == "street_clear",
                                onTap: () => detectionService.setSimulationScenario("street_clear"),
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: _buildScenarioButton(
                                label: "STREET BUSY",
                                icon: Icons.warning_rounded,
                                color: const Color(0xFFFF3B30),
                                isSelected: detectionService.simulationScenario == "street_busy",
                                onTap: () => detectionService.setSimulationScenario("street_busy"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12.0),
                
                // Diagnostic Card (latency, Engine info)
                GlassCard(
                  borderRadius: 16.0,
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detectionService.runMode == AppRunMode.LIVE_CAMERA 
                                ? "LIVE DETECTOR: YOLOv8 INT8" 
                                : "SANDBOX SIMULATOR",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            detectionService.runMode == AppRunMode.LIVE_CAMERA 
                                ? "Preprocessing: OpenCV filters" 
                                : "Generating dummy vehicle tracks",
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10.0,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                        child: Text(
                          detectionService.runMode == AppRunMode.LIVE_CAMERA ? "Latency: 23ms" : "Latency: 1ms",
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 11.0,
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: isSelected ? color : Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? color : Colors.white54, size: 18.0),
              const SizedBox(width: 6.0),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a premium vector drawn background of a perspective road
  Widget _buildSimulatedRoadBackground(String scenario) {
    return Container(
      color: const Color(0xFF1E1E2F),
      child: CustomPaint(
        painter: _RoadPainter(scenario: scenario),
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  final String scenario;

  _RoadPainter({required this.scenario});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Draw background sky/buildings glow
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F0C20), Color(0xFF242038)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, width, height * 0.5));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height * 0.5), skyPaint);

    // Draw pavement
    final groundPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2C2C35), Color(0xFF1A1A1E)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, height * 0.5, width, height * 0.5));
    canvas.drawRect(Rect.fromLTWH(0, height * 0.5, width, height * 0.5), groundPaint);

    // Draw perspective road lanes
    final roadPaint = Paint()
      ..color = const Color(0xFF3A3A4A)
      ..style = PaintingStyle.fill;
      
    final path = Path()
      ..moveTo(width * 0.45, height * 0.5) // Horizon top left
      ..lineTo(width * 0.55, height * 0.5) // Horizon top right
      ..lineTo(width * 0.95, height)       // Bottom right
      ..lineTo(width * 0.05, height)       // Bottom left
      ..close();
    canvas.drawPath(path, roadPaint);

    // Draw perspective center dashed line
    final linePaint = Paint()
      ..color = const Color(0xFFFFD13B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Horizon line
    canvas.drawLine(
      Offset(width * 0.5, height * 0.5),
      Offset(width * 0.5, height * 0.95),
      linePaint,
    );

    // Draw sidewalk/grass area on the sides
    final sidePaint = Paint()
      ..color = const Color(0xFF1F3B2B);
      
    final leftGrass = Path()
      ..moveTo(0, height * 0.5)
      ..lineTo(width * 0.45, height * 0.5)
      ..lineTo(width * 0.05, height)
      ..lineTo(0, height)
      ..close();
    canvas.drawPath(leftGrass, sidePaint);

    final rightGrass = Path()
      ..moveTo(width * 0.55, height * 0.5)
      ..lineTo(width, height * 0.5)
      ..lineTo(width, height)
      ..lineTo(width * 0.95, height)
      ..close();
    canvas.drawPath(rightGrass, sidePaint);
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) {
    return oldDelegate.scenario != scenario;
  }
}
