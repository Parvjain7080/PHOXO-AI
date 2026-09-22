import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:llamadart/llamadart.dart';

import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/llm_service.dart';
import '../services/chat_storage_service.dart';
import '../services/news_service.dart';
import '../services/remote_inference_service.dart';
import '../services/voice_service.dart';

class ChatController extends GetxController {
  final LlmService _llm = Get.find<LlmService>();
  final RemoteInferenceService _remote = Get.find<RemoteInferenceService>();
  final NewsService _news = Get.find<NewsService>();
  final ChatStorageService _storage = Get.find<ChatStorageService>();
  final VoiceService _voice = Get.find<VoiceService>();

  final chats = <ChatModel>[].obs;
  final activeChatId = RxnString();

  // Set by main.dart's overlay listener when a photo is picked from the
  // floating bubble's typing pad. HomeScreen watches this and drops the
  // image into the input bar so the user can type their own question
  // about it — same as tapping the attach-image button manually.
  final pendingOverlayImage = RxnString();
  final isGenerating = false.obs;
  final streamedResponse = ''.obs;
  final temperature = 0.7.obs;
  final systemPrompt = ''.obs;

  StreamSubscription<String>? _genSub;

  // Appended to the prompt only for voice-originated messages — keeps
  // spoken replies short and direct instead of trailing off into
  // "How can I help you today?" style follow-up questions.
  static const String _voiceInstruction =
      'Answer directly and concisely in 1-3 sentences suitable for being '
      'read aloud. Do not ask the user a follow-up question at the end of '
      'your reply.';

  @override
  void onInit() {
    super.onInit();
    _loadChats();
    temperature.value = _storage.defaultTemperature;
    systemPrompt.value = _storage.globalSystemPrompt;
  }

  void _loadChats() {
    chats.value = _storage.getAllChats();
  }

  ChatModel? get activeChat {
    if (activeChatId.value == null) return null;
    try {
      return chats.firstWhere((c) => c.id == activeChatId.value);
    } catch (_) {
      return null;
    }
  }

  /// Create a new chat and switch to it.
  void newChat() {
    final chat = ChatModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      systemPrompt: systemPrompt.value,
    );
    chats.insert(0, chat);
    _storage.saveChat(chat);
    activeChatId.value = chat.id;
  }

  /// Switch to an existing chat.
  void switchChat(String id) {
    activeChatId.value = id;
    final chat = activeChat;
    if (chat != null) {
      systemPrompt.value = chat.systemPrompt;
    }
  }

  /// Delete a chat.
  void deleteChat(String id) {
    chats.removeWhere((c) => c.id == id);
    _storage.deleteChat(id);
    if (activeChatId.value == id) {
      activeChatId.value = chats.isNotEmpty ? chats.first.id : null;
    }
  }

  /// Send a user message and stream AI response.
  ///
  /// [speakReply]: pass true when this message came from voice input, so
  /// the assistant's reply gets spoken back via VoiceService once it's
  /// fully generated, and the model is told to answer directly without
  /// a trailing follow-up question.
  Future<void> sendMessage(
    String text, {
    String? modelFilename,
    String? imagePath,
    bool speakReply = false,
  }) async {
    if (text.trim().isEmpty && imagePath == null) return;
    final chat = activeChat;
    if (chat == null) return;

    String? imageBase64;
    if (imagePath != null) {
      final bytes = await File(imagePath).readAsBytes();
      imageBase64 = base64Encode(bytes);
    }

    final userMsg = MessageModel(
      role: MessageRole.user,
      content: text.trim(),
      imageBase64: imageBase64,
      imageMimeType: imagePath != null ? 'image/jpeg' : null,
    );
    chat.messages.add(userMsg);
    chat.autoTitle();
    chat.updatedAt = DateTime.now();

    if (chat.modelId.isEmpty && modelFilename != null) {
      chat.modelId = modelFilename;
    }
    _storage.saveChat(chat);
    chats.refresh();

    isGenerating.value = true;
    streamedResponse.value = '';
    final aiMsg = MessageModel(role: MessageRole.assistant, content: '');
    chat.messages.add(aiMsg);
    chats.refresh();

    bool hadError = false;

    try {
      final Stream<String> stream;

      // Check if we should and can use the laptop
      final canUseRemote = _remote.shouldUseRemote && await _remote.checkReachability();

      if (canUseRemote) {
        final remoteHistory = chat.messages
            .where((m) => !m.isSystem)
            .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.content})
            .toList();

        if (speakReply) {
          remoteHistory.insert(0, {'role': 'system', 'content': _voiceInstruction});
        }

        stream = _remote.generate(
          model: _storage.remoteModelName,
          messages: remoteHistory,
          imageBase64: imageBase64,
        );
      } else {
        final hasVision = imagePath != null && await _llm.checkSupportsVision();
        if (hasVision) {
          final prompt = speakReply ? '$_voiceInstruction\n\n${text.trim()}' : text.trim();
          stream = _llm.generateWithImage(imagePath: imagePath!, prompt: prompt);
        } else {
          String effectiveSystemPrompt = chat.systemPrompt.isNotEmpty ? chat.systemPrompt : systemPrompt.value;
          if (_news.isNewsQuery(text)) {
            effectiveSystemPrompt = '$effectiveSystemPrompt\n\n${_news.buildNewsContext()}';
          }
          if (speakReply) {
            effectiveSystemPrompt = '$effectiveSystemPrompt\n\n$_voiceInstruction';
          }

          final chatMessages = <LlamaChatMessage>[];
          if (effectiveSystemPrompt.isNotEmpty) {
            chatMessages.add(LlamaChatMessage(role: 'system', content: effectiveSystemPrompt));
          }
          for (final m in chat.messages.where((m) => !m.isSystem)) {
            chatMessages.add(LlamaChatMessage(
              role: m.isUser ? 'user' : 'assistant',
              content: m.content,
            ));
          }
          stream = _llm.generateChatCompletion(messages: chatMessages);
        }
      }

      await for (final token in stream) {
        streamedResponse.value += token;
        aiMsg.content = streamedResponse.value;
        chats.refresh();
      }
    } catch (e) {
      hadError = true;
      if (aiMsg.content.isEmpty) aiMsg.content = '⚠ Error: ${e.toString()}';
    } finally {
      isGenerating.value = false;
      streamedResponse.value = '';
      chat.updatedAt = DateTime.now();
      _storage.saveChat(chat);
      chats.refresh();
    }

    // Speak the reply only if this message came in via voice AND
    // generation actually succeeded — no point narrating an error string.
    if (speakReply && !hadError && aiMsg.content.trim().isNotEmpty) {
      _voice.speak(aiMsg.content);
    }
  }

  /// Stop current generation.
  void stopGeneration() {
    _llm.stopGeneration();
    isGenerating.value = false;
  }

  /// Update the system prompt for the active chat.
  void updateSystemPrompt(String prompt) {
    systemPrompt.value = prompt;
    final chat = activeChat;
    if (chat != null) {
      chat.systemPrompt = prompt;
      _storage.saveChat(chat);
    }
  }

  /// Set and persist the global system prompt.
  void setGlobalSystemPrompt(String prompt) {
    systemPrompt.value = prompt;
    _storage.globalSystemPrompt = prompt;
  }

  /// Clear global system prompt.
  void clearGlobalSystemPrompt() {
    systemPrompt.value = '';
    _storage.globalSystemPrompt = '';
  }

  void updateTemperature(double temp) {
    temperature.value = temp;
    _storage.defaultTemperature = temp;
  }

  @override
  void onClose() {
    _genSub?.cancel();
    super.onClose();
  }
}