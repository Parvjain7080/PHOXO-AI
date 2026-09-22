import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Wraps speech-to-text + text-to-speech. No manual language toggle —
/// listening uses the device's own default speech-recognition language,
/// and speaking auto-picks Hindi or English TTS voice based on whether
/// the AI's actual reply text contains Devanagari script.
///
/// isListening / isSpeaking are reactive (GetX .obs) so a full-screen
/// voice UI can react to state changes without any manual polling.
class VoiceService extends GetxService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttReady = false;
  bool _ttsHandlersSet = false;

  final RxBool isListening = false.obs;
  final RxBool isSpeaking = false.obs;

  static final RegExp _devanagari = RegExp(r'[\u0900-\u097F]');
  bool _looksHindi(String text) => _devanagari.hasMatch(text);

  Future<bool> init() async {
    _sttReady = await _stt.initialize(
      onError: (e) {
        debugPrint('🎤 STT error: $e');
        isListening.value = false;
      },
      onStatus: (s) {
        debugPrint('🎤 STT status: $s');
        if (s == 'done' || s == 'notListening') {
          isListening.value = false;
        }
      },
    );

    if (!_ttsHandlersSet) {
      _tts.setStartHandler(() => isSpeaking.value = true);
      _tts.setCompletionHandler(() => isSpeaking.value = false);
      _tts.setCancelHandler(() => isSpeaking.value = false);
      _tts.setErrorHandler((_) => isSpeaking.value = false);
      _ttsHandlersSet = true;
    }

    return _sttReady;
  }

  Future<void> startListening({
    required void Function(String text) onResult,
    void Function(String partial)? onPartial,
  }) async {
    if (!_sttReady) {
      final ok = await init();
      if (!ok) return;
    }
    if (_stt.isListening) return;

    isListening.value = true;
    await _stt.listen(
      onResult: (result) {
        if (result.finalResult) {
          isListening.value = false;
          onResult(result.recognizedWords);
        } else {
          onPartial?.call(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
    isListening.value = false;
  }

  /// Speaks [text] aloud, automatically switching the TTS voice to
  /// Hindi if the text contains Devanagari script, English otherwise.
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (!_ttsHandlersSet) await init();

    final locale = _looksHindi(trimmed) ? 'hi-IN' : 'en-IN';
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(0.48);
    await _tts.speak(trimmed);
  }

  /// Interrupts speech immediately — call from a "Stop" button while
  /// a long reply is being read aloud.
  Future<void> stopSpeaking() async {
    await _tts.stop();
    isSpeaking.value = false; // belt-and-suspenders; cancel handler should also fire
  }
}