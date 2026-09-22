import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'chat_storage_service.dart';

/// Talks to a laptop running Ollama over the local WiFi network,
/// falling back gracefully if it's unreachable.
class RemoteInferenceService extends GetxService {
  final ChatStorageService _storage = Get.find<ChatStorageService>();

  final isReachable = false.obs;
  final lastCheckTime = Rxn<DateTime>();

  String get serverUrl => _storage.remoteServerUrl.trim();
  bool get isConfigured => serverUrl.isNotEmpty;
  bool get shouldUseRemote => isConfigured && _storage.useRemoteWhenAvailable;

  Future<RemoteInferenceService> init() async {
    if (isConfigured) await checkReachability();
    return this;
  }

  /// Quick ping to see if the laptop server is currently reachable.
  Future<bool> checkReachability() async {
    if (!isConfigured) {
      isReachable.value = false;
      return false;
    }
    try {
      final response = await http
          .get(Uri.parse('$serverUrl/api/tags'))
          .timeout(const Duration(seconds: 3));
      isReachable.value = response.statusCode == 200;
    } catch (_) {
      isReachable.value = false;
    }
    lastCheckTime.value = DateTime.now();
    return isReachable.value;
  }

  /// Stream a chat response from the laptop, optionally with an image.
  Stream<String> generate({
    required String model,
    required List<Map<String, String>> messages,
    String? imageBase64,
  }) async* {
    final url = Uri.parse('$serverUrl/api/chat');

    final ollamaMessages = messages.map((m) {
      final msg = <String, dynamic>{
        'role': m['role'],
        'content': m['content'],
      };
      return msg;
    }).toList();

    // Attach image to the last user message, Ollama's expected format
    if (imageBase64 != null && ollamaMessages.isNotEmpty) {
      for (int i = ollamaMessages.length - 1; i >= 0; i--) {
        if (ollamaMessages[i]['role'] == 'user') {
          ollamaMessages[i]['images'] = [imageBase64];
          break;
        }
      }
    }

    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'model': model,
      'messages': ollamaMessages,
      'stream': true,
    });

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 15));

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.trim().isEmpty) continue;
          try {
            final json = jsonDecode(line);
            final content = json['message']?['content'];
            if (content != null && content is String && content.isNotEmpty) {
              yield content;
            }
            if (json['done'] == true) return;
          } catch (_) {
            // Skip malformed lines
          }
        }
      }
    } finally {
      client.close();
    }
  }
}