import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:image_picker/image_picker.dart';

const String _kAppPackageName = 'com.portableai.portable_ai_flutter';

@pragma('vm:entry-point')
void overlayMain() {
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatelessWidget {
  const _OverlayApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: OverlayBubble(),
      ),
    );
  }
}

class OverlayBubble extends StatefulWidget {
  const OverlayBubble({super.key});

  @override
  State<OverlayBubble> createState() => _OverlayBubbleState();
}

class _OverlayBubbleState extends State<OverlayBubble> {
  bool _expanded = false;
  final _textController = TextEditingController();

  double _dragDy = 0;
  static const double _removeThreshold = 260;

  // ============================================================
  // EXPAND / COLLAPSE
  // ============================================================

  Future<void> _expandPad() async {
    // Update the UI FIRST so the widget already shows the dim/pad layout
    // before the window resize happens — resizing first caused a brief
    // flash of the collapsed logo stretched across the new window size.
    if (mounted) setState(() => _expanded = true);
    try {
      // A realistic phone-screen size instead of an oversized guess —
      // requesting far more than any real display can cause the overlay
      // window to end up in a broken/unresponsive touch state.
      await FlutterOverlayWindow.resizeOverlay(1080, 2280, false);
    } catch (e) {
      debugPrint('❌ Expand error: $e');
    }
  }

  Future<void> _collapseBubble() async {
    try {
      await FlutterOverlayWindow.resizeOverlay(72, 72, false);
      if (mounted) setState(() => _expanded = false);
      _textController.clear();
    } catch (e) {
      debugPrint('❌ Collapse error: $e');
    }
  }

  // ============================================================
  // DRAG (collapsed bubble only)
  // ============================================================

  void _onPanStart(DragStartDetails details) => _dragDy = 0;

  Future<void> _onPanUpdate(DragUpdateDetails details) async {
    _dragDy += details.delta.dy;
    try {
      await FlutterOverlayWindow.moveOverlay(
        OverlayPosition(details.globalPosition.dx, details.globalPosition.dy),
      );
    } catch (e) {
      debugPrint('❌ Move error: $e');
    }
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    if (_dragDy >= _removeThreshold) {
      await FlutterOverlayWindow.closeOverlay();
    }
    _dragDy = 0;
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _openApp() async {
    final intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      package: _kAppPackageName,
      componentName: '$_kAppPackageName.MainActivity',
      flags: <int>[268435456], // FLAG_ACTIVITY_NEW_TASK
    );
    await intent.launch();
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    await FlutterOverlayWindow.shareData('chat::${Uri.encodeComponent(text)}');
    await _openApp();
    await _collapseBubble();
  }

  Future<void> _openVoice() async {
    await FlutterOverlayWindow.shareData('voice');
    await _openApp();
    await _collapseBubble();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    await FlutterOverlayWindow.shareData(
      'upload::${Uri.encodeComponent(picked.path)}',
    );
    await _openApp();
    await _collapseBubble();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return GestureDetector(
        onTap: _expandPad,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Image.asset(
          'lib/assets/app_logo.png',
          width: 72,
          height: 72,
          errorBuilder: (_, __, ___) => Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF6366F1),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 34),
          ),
        ),
      );
    }

    // Expanded: full-screen dim scrim, X top-left, typing pad at bottom —
    // laid out like Android's Assistant/Circle-to-Search overlay.
    return Stack(
      children: [
        // Dim scrim across the whole overlay (approximates blur-behind;
        // true blur of content behind the window needs native code).
        Positioned.fill(
          child: GestureDetector(
            onTap: _collapseBubble, // tap outside the pad also closes it
            child: Container(color: Colors.black.withOpacity(0.55)),
          ),
        ),

        // Close (X) — top-left, like the reference layout.
        Positioned(
          top: 40,
          left: 16,
          child: SafeArea(
            child: GestureDetector(
              onTap: _collapseBubble,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.4),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
              ),
            ),
          ),
        ),

        // Typing pad — anchored near the bottom.
        Positioned(
          left: 20,
          right: 20,
          bottom: 60,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xF0121620),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image_outlined, color: Colors.white70),
                      onPressed: _pickPhoto,
                      tooltip: 'Ask about a photo',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Ask anything...',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendText(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.mic_none_rounded, color: Colors.white70),
                      onPressed: _openVoice,
                      tooltip: 'Voice mode',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}