import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/safety_engine.dart';
import '../services/alert_service.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final safetyEngine = Provider.of<SafetyEngine>(context);
    final alertService = Provider.of<AlertService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "AI Calibration Settings",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
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
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              children: [
                // Section: Proximity calibration
                _buildSectionHeader("AI PROXIMITY CALIBRATION"),
                const SizedBox(height: 12.0),
                GlassCard(
                  borderRadius: 20.0,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Warning Danger Distance",
                            style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "${safetyEngine.dangerThresholdDistance.toStringAsFixed(0)} meters",
                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 16.0, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        "Sets the buffer zone distance. If an approaching vehicle enters this range, the warning alerts trigger immediately.",
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12.0),
                      ),
                      const SizedBox(height: 16.0),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.cyanAccent,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.cyan,
                          overlayColor: Colors.cyan.withOpacity(0.2),
                        ),
                        child: Slider(
                          value: safetyEngine.dangerThresholdDistance,
                          min: 5.0,
                          max: 30.0,
                          divisions: 5,
                          onChanged: (val) {
                            safetyEngine.updateDangerThreshold(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28.0),

                // Section: Alert triggers
                _buildSectionHeader("ALERT NOTIFICATION SETTINGS"),
                const SizedBox(height: 12.0),
                GlassCard(
                  borderRadius: 20.0,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      // Voice warnings toggle
                      _buildSwitchTile(
                        title: "Voice Warnings (TTS)",
                        subtitle: "Speaks aloud safety verdicts and approaches.",
                        icon: Icons.record_voice_over_rounded,
                        value: alertService.ttsEnabled,
                        onChanged: (val) {
                          alertService.setTtsEnabled(val);
                        },
                      ),
                      const Divider(color: Colors.white10),
                      // Haptic Vibration warnings toggle
                      _buildSwitchTile(
                        title: "Vibration Haptics",
                        subtitle: "Pulsing vibration alert codes on danger.",
                        icon: Icons.vibration_rounded,
                        value: alertService.hapticsEnabled,
                        onChanged: (val) {
                          alertService.setHapticsEnabled(val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36.0),

                // Reset Button
                ElevatedButton(
                  onPressed: () {
                    safetyEngine.updateDangerThreshold(15.0);
                    alertService.setTtsEnabled(true);
                    alertService.setHapticsEnabled(true);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Calibration metrics reset to factory defaults."),
                        backgroundColor: Colors.indigo,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.08),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: const Text(
                    "RESET TO FACTORY DEFAULTS",
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12.0,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.0),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12.0),
      ),
      secondary: Icon(
        icon,
        color: value ? Colors.cyanAccent : Colors.white38,
        size: 24.0,
      ),
      activeColor: Colors.cyanAccent,
      activeTrackColor: Colors.cyan.withOpacity(0.3),
      inactiveThumbColor: Colors.grey,
      inactiveTrackColor: Colors.white10,
      contentPadding: EdgeInsets.zero,
    );
  }
}
