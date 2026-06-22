import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

class AlertService with ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  
  bool _ttsEnabled = true;
  bool _hapticsEnabled = true;
  
  DateTime? _lastSpeechTime;
  String? _lastSpokenText;

  bool get ttsEnabled => _ttsEnabled;
  bool get hapticsEnabled => _hapticsEnabled;

  AlertService() {
    _initTts();
  }

  void _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.55); // Slightly slower speech is easier for elderly and visually impaired to hear
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  void setTtsEnabled(bool enabled) {
    _ttsEnabled = enabled;
    notifyListeners();
  }

  void setHapticsEnabled(bool enabled) {
    _hapticsEnabled = enabled;
    notifyListeners();
  }

  /// Triggers safety audio and physical vibrations.
  /// Decides based on the verdict string: "SAFE", "CAUTION", or "DANGER".
  void triggerAlert(String verdict, {String? customMessage}) async {
    final now = DateTime.now();
    
    String message;
    if (customMessage != null) {
      message = customMessage;
    } else {
      switch (verdict) {
        case "DANGER":
          message = "Stop! Vehicle approaching!";
          break;
        case "CAUTION":
          message = "Caution! Vehicle approaching!";
          break;
        case "SAFE":
        default:
          message = "Safe to cross. Walk carefully.";
          break;
      }
    }

    // Play Vibration
    if (_hapticsEnabled) {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        if (verdict == "DANGER") {
          // Double buzz alert for danger
          Vibration.vibrate(pattern: [0, 500, 200, 500]);
        } else if (verdict == "CAUTION") {
          // Single medium buzz alert for caution
          Vibration.vibrate(duration: 350);
        } else {
          // Single short gentle tap vibration for safe confirmation
          Vibration.vibrate(duration: 100);
        }
      }
    }

    // Speak text warning (with a 3-second cooldown to prevent overlapping audio)
    if (_ttsEnabled) {
      if (_lastSpeechTime == null || 
          now.difference(_lastSpeechTime!) > const Duration(seconds: 3) || 
          _lastSpokenText != message) {
        _lastSpeechTime = now;
        _lastSpokenText = message;
        
        await _tts.speak(message);
      }
    }
  }

  void stopAllAlerts() async {
    await _tts.stop();
    await Vibration.cancel();
  }
}
