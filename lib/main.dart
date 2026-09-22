import 'dart:async';
import 'services/news_service.dart';
import 'overlay/overlay_bubble.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'models/chat_model.dart';
import 'models/message_model.dart';
import 'theme/app_theme.dart';
import 'bindings/app_bindings.dart';
import 'controllers/theme_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/model_controller.dart';
import 'screens/voice_mode_screen.dart';
// ignore: unused_import
import 'screens/splash_screen.dart'; // needed in routes/app_routes.dart
import 'routes/app_routes.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: OverlayBubble(),
      ),
    ),
  );
}

Future<void> main() async {
  // Wrap entire app in error zone to catch native/async crashes
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Catch Flutter framework errors
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exception}');
    };

    // Catch unhandled platform errors
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('PlatformError: $error\n$stack');
      return true;
    };

    // Init Hive
    final appDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDir.path);

    // Register Hive adapters
    Hive.registerAdapter(ChatModelAdapter());
    Hive.registerAdapter(MessageModelAdapter());
    Hive.registerAdapter(MessageRoleAdapter());

    // Open Hive boxes
    await Hive.openBox<ChatModel>('chats');
    await Hive.openBox('settings');
    await Hive.openBox('models_meta');

    // Load theme preference
    final themeController = Get.put(ThemeController());

    // 🔥 LISTEN FOR FLOATING OVERLAY ACTIONS
    FlutterOverlayWindow.overlayListener.listen((event) {
      debugPrint('🔥 OVERLAY ACTION RECEIVED: $event');
      final e = event.toString();

      if (e.startsWith('chat::')) {
        final text = Uri.decodeComponent(e.substring(6));
        Get.offAllNamed(AppRoutes.home);
        Get.find<ChatController>().sendMessage(
          text,
          modelFilename: Get.find<ModelController>().selectedModelFilename.value,
        );
      } else if (e.startsWith('upload::')) {
        final path = Uri.decodeComponent(e.substring(8));
        Get.offAllNamed(AppRoutes.home);
        Get.find<ChatController>().pendingOverlayImage.value = path;
      } else if (e == 'voice') {
        Get.offAllNamed(AppRoutes.home);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.to(() => const VoiceModeScreen());
        });
      }
    });

    runApp(
      PortableAIApp(
        themeController: themeController,
      ),
    );
  }, (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
  });
}

class PortableAIApp extends StatelessWidget {
  final ThemeController themeController;
  
  const PortableAIApp({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Phoxo AI',
      debugShowCheckedModeBanner: false,
      themeMode: themeController.themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      initialBinding: AppBindings(),
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.pages,
    );
  }
}
