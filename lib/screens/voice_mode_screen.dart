import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';
import '../controllers/chat_controller.dart';
import '../controllers/model_controller.dart';
import '../services/voice_service.dart';

/// Full-screen, text-free voice interaction — like ChatGPT's voice mode.
/// No chat bubbles are shown here; the conversation still gets saved to
/// history via ChatController exactly like a normal message, you just
/// don't see it while this screen is open.
class VoiceModeScreen extends StatefulWidget {
  const VoiceModeScreen({super.key});

  @override
  State<VoiceModeScreen> createState() => _VoiceModeScreenState();
}

class _VoiceModeScreenState extends State<VoiceModeScreen>
    with SingleTickerProviderStateMixin {
  final _voice = Get.find<VoiceService>();
  final _chatCtrl = Get.find<ChatController>();
  final _modelCtrl = Get.find<ModelController>();

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    // Start listening the moment this screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _voice.stopListening();
    _voice.stopSpeaking();
    super.dispose();
  }

  Future<void> _listen() async {
    if (_chatCtrl.activeChat == null) {
      _chatCtrl.newChat();
    }
    await _voice.startListening(
      onResult: (text) {
        if (text.trim().isEmpty) return;
        _chatCtrl.sendMessage(
          text,
          modelFilename: _modelCtrl.selectedModelFilename.value,
          speakReply: true,
        );
      },
    );
  }

  String _statusFor({
    required bool listening,
    required bool thinking,
    required bool speaking,
  }) {
    if (listening) return 'Listening...';
    if (thinking) return 'Thinking...';
    if (speaking) return 'Speaking...';
    return 'Tap to speak';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Obx(() {
          final listening = _voice.isListening.value;
          final thinking = _chatCtrl.isGenerating.value;
          final speaking = _voice.isSpeaking.value;
          final active = listening || speaking;

          return Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 28),
                  onPressed: () => Get.back(),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (!listening && !thinking && !speaking) _listen();
                },
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, child) {
                    final scale = active
                        ? 1.0 + (_pulseCtrl.value * 0.12)
                        : 1.0;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.accentGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(active ? 0.45 : 0.2),
                          blurRadius: active ? 50 : 25,
                          spreadRadius: active ? 8 : 2,
                        ),
                      ],
                    ),
                    child: thinking
                        ? const Padding(
                            padding: EdgeInsets.all(50),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Icon(
                            listening ? Icons.mic_rounded : Icons.bolt_rounded,
                            color: Colors.white,
                            size: 64,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _statusFor(listening: listening, thinking: thinking, speaking: speaking),
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const Spacer(),
              // Stop button — only shown while a reply is being read aloud.
              AnimatedOpacity(
                opacity: speaking ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !speaking,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: OutlinedButton.icon(
                      onPressed: () => _voice.stopSpeaking(),
                      icon: const Icon(Icons.stop_rounded, color: Colors.white),
                      label: const Text('Stop', style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}