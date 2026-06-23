import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

class AlertService with ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _ttsEnabled = true;
  bool _hapticsEnabled = true;
  
  DateTime? _lastSpeechTime;
  String? _lastSpokenText;
  String? _lastVerdict;

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

  void _playAudioFile(String fileName) async {
    try {
      await _audioPlayer.stop(); // Stop currently playing audio to avoid overlay
      await _audioPlayer.play(AssetSource('Audio/$fileName'));
    } catch (e) {
      debugPrint("Error playing audio asset: $e");
    }
  }

  /// Triggers safety audio and physical vibrations.
  /// Decides based on the verdict string: "SAFE", "CAUTION", or "DANGER".
  void triggerAlert(String verdict, {String? customMessage}) async {
    final now = DateTime.now();
    
    // Track state changes to avoid spamming "SAFE"
    final isStateChanged = _lastVerdict != verdict;
    final isCooldownElapsed = _lastSpeechTime == null || 
        now.difference(_lastSpeechTime!) > const Duration(seconds: 4);

    if (isStateChanged || (verdict != "SAFE" && isCooldownElapsed)) {
      _lastSpeechTime = now;
      _lastVerdict = verdict;

      // Play Vibration
      if (_hapticsEnabled) {
        final hasVibrator = await Vibration.hasVibrator() ?? false;
        if (hasVibrator) {
          // Cancel any ongoing continuous vibrations first
          await Vibration.cancel();
          
          if (verdict == "DANGER") {
            // Red Alert: Continuous vibration pattern
            Vibration.vibrate(pattern: [0, 500, 200, 500], repeat: 0);
          } else if (verdict == "WARNING" || verdict == "CAUTION") {
            // Yellow Alert: Two medium vibrations
            Vibration.vibrate(pattern: [0, 250, 150, 250]);
          } else {
            // Green Alert: Single short vibration
            Vibration.vibrate(duration: 100);
          }
        }
      }

      // Play Voice Messages (MP3 audio files from assets)
      if (_ttsEnabled) {
        if (verdict == "SAFE") {
          _playAudioFile("Now Safe.mp3");
          Future.delayed(const Duration(milliseconds: 1600), () {
            if (_lastVerdict == "SAFE") {
              _tts.speak("Safe to cross.");
            }
          });
        } else if (verdict == "DANGER") {
          _playAudioFile("Not Safe.mp3");
          Future.delayed(const Duration(milliseconds: 1600), () {
            if (_lastVerdict == "DANGER") {
              _tts.speak("Warning. Vehicle approaching. Do not cross.");
            }
          });
        } else if (verdict == "WARNING") {
          _playAudioFile("Not Safe.mp3");
          Future.delayed(const Duration(milliseconds: 1600), () {
            if (_lastVerdict == "WARNING") {
              _tts.speak("Please wait. Vehicle detected.");
            }
          });
        } else if (verdict == "CAUTION") {
          _playAudioFile("Not Safe.mp3");
          Future.delayed(const Duration(milliseconds: 1600), () {
            if (_lastVerdict == "CAUTION") {
              _tts.speak("Please be careful.");
            }
          });
        }
      }
    }
  }

  void stopAllAlerts() async {
    try {
      await _tts.stop();
      await _audioPlayer.stop();
      await Vibration.cancel();
    } catch (e) {
      debugPrint("Error stopping alerts: $e");
    }
  }
}
