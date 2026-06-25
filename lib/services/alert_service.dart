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
  /// Decides based on the verdict string: "NOT_SAFE", "SAFE_STOPPED", or "SAFE_NO_VEHICLES".
  void triggerAlert(String verdict, {String? customMessage}) async {
    final now = DateTime.now();
    
    // Cooldown check to avoid spamming voice prompts
    final isStateChanged = _lastVerdict != verdict;
    final isCooldownElapsed = _lastSpeechTime == null || 
        now.difference(_lastSpeechTime!) > const Duration(seconds: 4);

    if (isStateChanged || (verdict == "NOT_SAFE" && isCooldownElapsed)) {
      _lastSpeechTime = now;
      _lastVerdict = verdict;

      // Play Vibration
      if (_hapticsEnabled) {
        final hasVibrator = await Vibration.hasVibrator() ?? false;
        if (hasVibrator) {
          // Cancel any ongoing continuous vibrations first
          await Vibration.cancel();
          
          if (verdict == "NOT_SAFE") {
            // Red Alert: Continuous danger vibration pattern
            Vibration.vibrate(pattern: [0, 500, 200, 500], repeat: 0);
          } else {
            // Green Alert (SAFE_STOPPED or SAFE_NO_VEHICLES): Single short vibration
            Vibration.vibrate(duration: 100);
          }
        }
      }

      // Play Voice Messages (MP3 audio files from assets + Text-to-speech)
      if (_ttsEnabled) {
        if (verdict == "NOT_SAFE") {
          _playAudioFile("Not Safe.mp3");
          Future.delayed(const Duration(milliseconds: 1600), () {
            if (_lastVerdict == "NOT_SAFE") {
              _tts.speak("Warning. Vehicle approaching. Do not cross.");
            }
          });
        } else if (verdict == "SAFE_STOPPED") {
          _playAudioFile("Now Safe.mp3");
          Future.delayed(const Duration(milliseconds: 1600), () {
            if (_lastVerdict == "SAFE_STOPPED") {
              _tts.speak("You may walk now. Road is safe.");
            }
          });
        } else if (verdict == "SAFE_NO_VEHICLES") {
          _playAudioFile("Now Safe.mp3");
          Future.delayed(const Duration(milliseconds: 1600), () {
            if (_lastVerdict == "SAFE_NO_VEHICLES") {
              _tts.speak("Safe to cross.");
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
