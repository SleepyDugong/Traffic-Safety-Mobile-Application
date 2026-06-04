import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/detection_service.dart';
import '../widgets/glass_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final detectionService = Provider.of<DetectionService>(context);
    
    return Scaffold(
      body: Stack(
        children: [
          // Premium Glowing Space Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Slate 900
                  Color(0xFF020617), // Slate 950
                  Color(0xFF1E1E38), // Custom Deep Indigo
                ],
              ),
            ),
          ),
          
          // Glowing Ambient Orbs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.15), // Indigo Glow
                    blurRadius: 100,
                    spreadRadius: 50,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.12), // Emerald Glow
                    blurRadius: 80,
                    spreadRadius: 40,
                  )
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Brand Icon & Title
                    Icon(
                      Icons.traffic_rounded,
                      size: 80.0,
                      color: const Color(0xFF38BDF8), // Light Blue
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      "CROSSING ASSISTANT",
                      style: TextStyle(
                        fontSize: 28.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      "AI-Powered Real-Time Pedestrian Safety",
                      style: TextStyle(
                        fontSize: 16.0,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48.0),
                    
                    // Main Mode Selection Panel
                    GlassCard(
                      borderRadius: 24.0,
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text(
                            "Select Engine Mode",
                            style: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          
                          // Simulation Card
                          _buildModeCard(
                            context: context,
                            title: "Simulation Sandbox",
                            subtitle: "Mock feeds, safety analysis presentation.",
                            icon: Icons.splitscreen_rounded,
                            activeColor: const Color(0xFF38BDF8),
                            isSelected: detectionService.runMode == AppRunMode.SIMULATION,
                            onTap: () {
                              detectionService.setRunMode(AppRunMode.SIMULATION);
                            },
                          ),
                          const SizedBox(height: 12.0),
                          
                          // Live Android Camera Card
                          _buildModeCard(
                            context: context,
                            title: "Live Camera (Android)",
                            subtitle: "Quantized YOLOv8 AI inference & OpenCV.",
                            icon: Icons.videocam_rounded,
                            activeColor: const Color(0xFF10B981),
                            isSelected: detectionService.runMode == AppRunMode.LIVE_CAMERA,
                            onTap: () {
                              detectionService.setRunMode(AppRunMode.LIVE_CAMERA);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    
                    // Navigation Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildNavButton(
                            context: context,
                            label: "LAUNCH HUD",
                            icon: Icons.play_arrow_rounded,
                            color: const Color(0xFF10B981),
                            onTap: () {
                              Navigator.pushNamed(context, '/camera');
                            },
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: _buildNavButton(
                            context: context,
                            label: "SYSTEM INFO",
                            icon: Icons.info_outline_rounded,
                            color: const Color(0xFF6366F1),
                            onTap: () {
                              Navigator.pushNamed(context, '/info');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Settings Floating Button
                    TextButton.icon(
                      icon: const Icon(Icons.settings_rounded, color: Colors.white54),
                      label: const Text(
                        "AI Calibration Settings",
                        style: TextStyle(color: Colors.white70),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/settings');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color activeColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          color: isSelected ? activeColor.withOpacity(0.15) : Colors.white.withOpacity(0.02),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white.withOpacity(0.1),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? activeColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              ),
              padding: const EdgeInsets.all(10.0),
              child: Icon(
                icon,
                color: isSelected ? activeColor : Colors.white60,
                size: 24.0,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: activeColor,
                size: 24.0,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        gradient: LinearGradient(
          colors: [color, color.withRed(100).withBlue(100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24.0),
              const SizedBox(width: 8.0),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
