import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Wraps permission checks and show/hide calls for the floating bubble.
/// Call OverlayService.show() from a button in your Settings screen
/// (e.g. "Enable floating assistant").
class OverlayService {
  static Future<bool> hasPermission() =>
      FlutterOverlayWindow.isPermissionGranted();

  static Future<void> requestPermission() =>
      FlutterOverlayWindow.requestPermission();

  static Future<bool> isShowing() => FlutterOverlayWindow.isActive();

  static Future<void> show() async {
    debugPrint('🟦 OverlayService.show() called');

    final granted = await hasPermission();
    debugPrint('🟦 hasPermission = $granted');

    if (!granted) {
      debugPrint('🟦 requesting permission...');
      await requestPermission();
      final grantedNow = await hasPermission();
      debugPrint('🟦 hasPermission after request = $grantedNow');
      if (!grantedNow) {
        debugPrint('🟥 permission not granted — aborting');
        return;
      }
    }

    // Force a clean state, but never let this hang forever — some
    // plugin versions don't resolve closeOverlay() quickly when
    // nothing is currently showing.
    try {
      await FlutterOverlayWindow.closeOverlay()
          .timeout(const Duration(seconds: 2));
      debugPrint('🟦 closeOverlay done (or nothing to close)');
    } catch (e) {
      debugPrint('🟨 closeOverlay skipped/timed out: $e');
    }

    await Future.delayed(const Duration(milliseconds: 150));

    try {
      await FlutterOverlayWindow.showOverlay(
        height: 160,
        width: 160,
        alignment: OverlayAlignment.centerRight,
        flag: OverlayFlag.focusPointer,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.none, // we drag it ourselves
        overlayTitle: 'Uncensored Local AI',
        overlayContent: 'Tap for quick actions',
      ).timeout(const Duration(seconds: 5));
      debugPrint('✅ showOverlay completed');
    } catch (e, stack) {
      debugPrint('🟥 showOverlay failed: $e');
      debugPrint('$stack');
      rethrow; // let the caller's .catchError show it in a snackbar
    }
  }

  static Future<void> hide() => FlutterOverlayWindow.closeOverlay();
}