import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({Key? key}) : super(key: key);

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      "title": "System Architecture",
      "icon": Icons.account_tree_rounded,
      "color": Color(0xFF6366F1), // Indigo
      "content": "The application splits workload into two domains:\n\n"
          "1. Dart/Flutter UI Layer: Manages user inputs, HUD overlays, Safety Decision verdicts, TTS audio outputs, and haptic buzzer patterns.\n\n"
          "2. Kotlin Android Layer: Grabs raw frames from Camera2 API, processes formats through OpenCV filters, executes YOLOv8 model inference on quantized TFLite, tracks motion offsets, and returns JSON bounding box values to Flutter.",
    },
    {
      "title": "OpenCV Frame Processing",
      "icon": Icons.photo_filter_rounded,
      "color": Color(0xFF38BDF8), // Cyan
      "content": "To maximize frame rate and precision on low-power devices:\n\n"
          "• Formats conversion: Raw camera buffers are converted to normalized YUV-to-RGB arrays.\n"
          "• Noise suppression: Bilateral Gaussian blur filters are applied on native memory buffers to reduce glare and rain streaks.\n"
          "• Downsampling: Images are cropped and scaled to 640x640 resolution matching YOLOv8 network tensors, scaling float ranges to [0.0, 1.0].",
    },
    {
      "title": "Quantized YOLOv8 AI Model",
      "icon": Icons.psychology_rounded,
      "color": Color(0xFF10B981), // Green
      "content": "Our machine learning pipeline uses an INT8 Quantized YOLOv8 Nano model:\n\n"
          "• Normal weights are compressed from 32-bit floats to 8-bit integers, yielding a 4x reduction in size with < 1.5% loss in accuracy.\n"
          "• On-device execution is accelerated via Android's NNAPI and GPU delegates.\n"
          "• Output tensors extract classes: cars, buses, trucks, motorcycles, and pedestrians.",
    },
    {
      "title": "Safety Decision Heuristics",
      "icon": Icons.rule_rounded,
      "color": Color(0xFFF59E0B), // Orange
      "content": "Verdicts are computed from bounding box sizes:\n\n"
          "• Proximity Heuristic: Box height divided by frame height determines distance. Closer vehicles take up more vertical screen pixels.\n"
          "• Motion Vectors: Area difference across successive frames determines vectors. If Area(t) > Area(t-1), the vehicle is APPROACHING; else RECEDING.\n"
          "• Verdict Code: DANGER triggers if any vehicle is under 5 meters, or under calibrated limits while approaching.",
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Project System Guides",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF020617)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24.0),
                
                // Swipeable Carousel PageView
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return _buildSlideCard(slide);
                    },
                  ),
                ),
                
                // Indicators Dots Row
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => _buildIndicatorDot(index == _currentPage, _slides[index]["color"]),
                    ),
                  ),
                ),

                // Swiping Instructions Text
                Text(
                  "SWIPE TO READ NEXT SLIDE",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 16.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideCard(Map<String, dynamic> slide) {
    final title = slide["title"] as String;
    final icon = slide["icon"] as IconData;
    final color = slide["color"] as Color;
    final content = slide["content"] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: GlassCard(
        borderRadius: 24.0,
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Slide Icon Circle
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
                border: Border.all(color: color.withOpacity(0.5), width: 1.5),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Icon(
                icon,
                color: color,
                size: 36.0,
              ),
            ),
            const SizedBox(height: 24.0),
            
            // Slide Title
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16.0),
            
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 20.0),
            
            // Slide Body Content
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 14.0,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorDot(bool isActive, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 6.0),
      height: 8.0,
      width: isActive ? 24.0 : 8.0,
      decoration: BoxDecoration(
        color: isActive ? color : Colors.white24,
        borderRadius: BorderRadius.circular(4.0),
      ),
    );
  }
}
