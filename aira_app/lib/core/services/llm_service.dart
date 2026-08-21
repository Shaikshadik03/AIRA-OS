import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/config/app_config.dart';
import 'package:aira_app/core/services/personality_engine.dart';
import 'package:aira_app/core/services/user_profile_service.dart';
import 'package:aira_app/core/services/memory_engine.dart';
import 'package:intl/intl.dart';


/// Enum representing the active LLM Provider.
enum LlmProvider { groq, gemini, openRouter }

/// Unified LLM Service Layer with Fallback Chain:
/// Groq (Primary) ──► Gemini (Fallback 1) ──► OpenRouter (Fallback 2)
///
/// Integrates PersonalityEngine, UserProfile, and MemoryEngine
/// to produce human-like, context-aware responses.
class LlmService {
  static final LlmService _instance = LlmService._internal();
  factory LlmService() => _instance;
  LlmService._internal();

  // Last provider that successfully responded
  LlmProvider _lastUsedProvider = LlmProvider.groq;
  LlmProvider get lastUsedProvider => _lastUsedProvider;
  String get lastProviderName => _lastUsedProvider.name.toUpperCase();

  // Test Flags for Proof-of-Work verification
  bool forceGroqFail = false;
  bool forceGeminiFail = false;

  final _personality = PersonalityEngine();
  final _userProfile = UserProfileService();
  final _memory = MemoryEngine();

  /// Convenience method for simple chat (used by FactExtractor etc.)
  Future<String> chat({
    required String userMessage,
    List<Map<String, dynamic>> conversationHistory = const [],
    String? systemPromptOverride,
  }) async {
    return callLlm(
      userMessage: userMessage,
      history: conversationHistory,
      systemPromptOverride: systemPromptOverride,
    );
  }

  /// Build the full system prompt dynamically with personality, profile, and memory.
  String _buildFullSystemPrompt({String? memoryContext, String? systemPromptOverride}) {
    if (systemPromptOverride != null && systemPromptOverride.isNotEmpty) {
      return systemPromptOverride;
    }

    final localTime = DateFormat('h:mm a, EEEE, MMM d').format(DateTime.now());

    // Get relevant memory facts (general context)
    final allFacts = _memory.getAllFactStrings();
    final topFacts = allFacts.take(8).toList();

    final prompt = _personality.buildSystemPrompt(
      userProfile: _userProfile.profile,
      memoryFacts: topFacts,
      localTime: localTime,
    );

    // Append any additional memory context (from chat provider)
    if (memoryContext != null && memoryContext.trim().isNotEmpty) {
      return '$prompt\n$memoryContext';
    }
    return prompt;
  }

  // ──────────────────── Unified API Entrypoint ────────────────────

  /// Main interface function: Executes LLM query with fallback chain.
  Future<String> callLlm({
    required String userMessage,
    List<Map<String, dynamic>>? history,
    String? base64Image,
    String? memoryContext,
    String? systemPromptOverride,
  }) async {
    // Build context-aware system prompt with personality + profile + memory
    final fullSystemPrompt = _buildFullSystemPrompt(
      memoryContext: memoryContext,
      systemPromptOverride: systemPromptOverride,
    );

    final conversationHistory = history ?? [];

    // ── IMAGE VISION ROUTING ──
    // Groq decommissioned vision preview models. Route vision requests to OpenRouter (gpt-4o-mini) or Gemini first.
    if (base64Image != null && base64Image.isNotEmpty) {
      try {
        debugPrint('[LLM VISION] Attempting Primary Vision Provider: OPENROUTER (gpt-4o-mini)...');
        final result = await _callOpenRouter(
          userMessage: userMessage,
          history: conversationHistory,
          systemPrompt: fullSystemPrompt,
          base64Image: base64Image,
        );
        _lastUsedProvider = LlmProvider.openRouter;
        debugPrint('[LLM VISION] ✅ Image Analyzed via OPENROUTER');
        return result;
      } catch (e) {
        debugPrint('[LLM VISION] ⚠️ OpenRouter Vision Failed ($e). Retrying on Gemini...');
        try {
          final result = await _callGemini(
            userMessage: userMessage,
            history: conversationHistory,
            systemPrompt: fullSystemPrompt,
            base64Image: base64Image,
          );
          _lastUsedProvider = LlmProvider.gemini;
          debugPrint('[LLM VISION] ✅ Image Analyzed via GEMINI');
          return result;
        } catch (gemErr) {
          debugPrint('[LLM VISION] ❌ All Vision Providers Failed: $gemErr');
          throw Exception('Could not process image ($gemErr). Please try again.');
        }
      }
    }

    // ── TEXT CHAT ROUTING (Groq -> Gemini -> OpenRouter) ──
    // ── STEP 1: Try Primary Provider (Groq) ──
    if (!forceGroqFail) {
      try {
        debugPrint('[LLM FALLBACK] Attempting Primary Provider: GROQ...');
        final result = await _callGroq(
          userMessage: userMessage,
          history: conversationHistory,
          systemPrompt: fullSystemPrompt,
          base64Image: base64Image,
        );
        _lastUsedProvider = LlmProvider.groq;
        debugPrint('[LLM FALLBACK] ✅ Responded via GROQ');
        return result;
      } catch (e) {
        debugPrint('[LLM FALLBACK] ⚠️ Groq Failed ($e). Retrying on Gemini (Fallback 1)...');
      }
    } else {
      debugPrint('[LLM FALLBACK] 🧪 TEST MODE: Groq call forced to FAIL. Retrying on Gemini...');
    }

    // ── STEP 2: Try Fallback 1 (Gemini) ──
    if (!forceGeminiFail) {
      try {
        debugPrint('[LLM FALLBACK] Attempting Fallback 1: GEMINI...');
        final result = await _callGemini(
          userMessage: userMessage,
          history: conversationHistory,
          systemPrompt: fullSystemPrompt,
          base64Image: base64Image,
        );
        _lastUsedProvider = LlmProvider.gemini;
        debugPrint('[LLM FALLBACK] ✅ Responded via GEMINI (Fallback 1)');
        return result;
      } catch (e) {
        debugPrint('[LLM FALLBACK] ⚠️ Gemini Failed ($e). Retrying on OpenRouter (Fallback 2)...');
      }
    } else {
      debugPrint('[LLM FALLBACK] 🧪 TEST MODE: Gemini call forced to FAIL. Retrying on OpenRouter...');
    }

    // ── STEP 3: Try Fallback 2 (OpenRouter) ──
    try {
      debugPrint('[LLM FALLBACK] Attempting Fallback 2: OPENROUTER...');
      final result = await _callOpenRouter(
        userMessage: userMessage,
        history: conversationHistory,
        systemPrompt: fullSystemPrompt,
        base64Image: base64Image,
      );
      _lastUsedProvider = LlmProvider.openRouter;
      debugPrint('[LLM FALLBACK] ✅ Responded via OPENROUTER (Fallback 2)');
      return result;
    } catch (e) {
      debugPrint('[LLM FALLBACK] ❌ All LLM Providers Failed: $e');
      return '⚠️ **AI API Key Setup**\n\n'
          'To start chatting with AIRA:\n'
          '1. Open **Settings ⚙️ → AI Model & API Keys**\n'
          '2. Paste your free **Groq API Key** (get one instantly at [console.groq.com/keys](https://console.groq.com/keys)) or **Gemini Key**.\n\n'
          '💡 *Tip: Your offline features like Laptop Remote Control, TickTick Tasks, DSA Problems, and Alarms work 100% anytime!*';
    }
  }

  // ──────────────────── Groq Provider (OpenAI Style) ────────────────────

  Future<String> _callGroq({
    required String userMessage,
    required List<Map<String, dynamic>> history,
    required String systemPrompt,
    String? base64Image,
  }) async {
    // Check SharedPreferences for user-provided custom Groq key first
    final prefs = await SharedPreferences.getInstance();
    final customKey = prefs.getString('aira_custom_groq_key')?.trim();
    final apiKey = (customKey != null && customKey.isNotEmpty)
        ? customKey
        : AppConfig.groqApiKey;

    if (apiKey.isEmpty) {
      throw Exception('Groq API Key is not set. Please add a free key in Settings.');
    }

    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.groqBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    ));

    final messages = _buildOpenAiMessages(
      userMessage: userMessage,
      history: history,
      systemPrompt: systemPrompt,
      base64Image: base64Image,
    );

    final model = base64Image != null ? 'llama-3.2-90b-vision-preview' : AppConfig.groqModel;

    final resp = await dio.post('/chat/completions', data: {
      'model': model,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 4096,
      'stream': false,
    });

    return _parseOpenAiResponse(resp.data);
  }

  // ──────────────────── Gemini Provider (Google Format) ────────────────────

  Future<String> _callGemini({
    required String userMessage,
    required List<Map<String, dynamic>> history,
    required String systemPrompt,
    String? base64Image,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final customKey = prefs.getString('aira_custom_gemini_key')?.trim();
    final apiKey = (customKey != null && customKey.isNotEmpty)
        ? customKey
        : AppConfig.geminiApiKey;

    if (apiKey.isEmpty) {
      throw Exception('Gemini API Key is not configured.');
    }

    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.geminiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    final payload = formatForGemini(
      userMessage: userMessage,
      history: history,
      systemPrompt: systemPrompt,
      base64Image: base64Image,
    );

    final model = AppConfig.geminiModel;

    final resp = await dio.post(
      '/models/$model:generateContent',
      queryParameters: {'key': apiKey},
      data: payload,
    );

    return parseGeminiResponse(resp.data);
  }

  // ──────────────────── OpenRouter Provider (OpenAI Style) ────────────────────

  Future<String> _callOpenRouter({
    required String userMessage,
    required List<Map<String, dynamic>> history,
    required String systemPrompt,
    String? base64Image,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final customKey = prefs.getString('aira_custom_openrouter_key')?.trim();
    final apiKey = (customKey != null && customKey.isNotEmpty)
        ? customKey
        : AppConfig.openRouterApiKey;

    if (apiKey.isEmpty) {
      throw Exception('OpenRouter API Key is not configured.');
    }

    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.openRouterBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 40),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': 'https://aira.app',
        'X-Title': 'AIRA OS',
        'Content-Type': 'application/json',
      },
    ));

    final messages = _buildOpenAiMessages(
      userMessage: userMessage,
      history: history,
      systemPrompt: systemPrompt,
      base64Image: base64Image,
    );

    final model = (base64Image != null && base64Image.isNotEmpty)
        ? 'openai/gpt-4o-mini'
        : AppConfig.openRouterModel;

    final resp = await dio.post('/chat/completions', data: {
      'model': model,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 4096,
      'stream': false,
    });

    return _parseOpenAiResponse(resp.data);
  }

  // ──────────────────── Helpers & Adapters ────────────────────

  /// OpenAI-style request builder (reused for Groq and OpenRouter).
  List<Map<String, dynamic>> _buildOpenAiMessages({
    required String userMessage,
    required List<Map<String, dynamic>> history,
    required String systemPrompt,
    String? base64Image,
  }) {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    if (base64Image != null) {
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': userMessage},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
          }
        ]
      });
    } else {
      messages.addAll(history);
      messages.add({'role': 'user', 'content': userMessage});
    }

    return messages;
  }

  /// OpenAI-style response parser.
  String _parseOpenAiResponse(dynamic data) {
    if (data is Map && data['choices'] != null && (data['choices'] as List).isNotEmpty) {
      final content = data['choices'][0]['message']?['content'];
      if (content != null) return content.toString().trim();
    }
    throw Exception('Invalid OpenAI-style LLM response structure');
  }

  /// Adapter function: Converts standard messages & system prompt into Gemini API shape.
  Map<String, dynamic> formatForGemini({
    required String userMessage,
    required List<Map<String, dynamic>> history,
    required String systemPrompt,
    String? base64Image,
  }) {
    final contents = <Map<String, dynamic>>[];

    // Add conversation history
    for (final m in history) {
      final role = m['role'] == 'assistant' ? 'model' : 'user';
      final content = m['content'];
      if (content is String && content.isNotEmpty) {
        contents.add({
          'role': role,
          'parts': [
            {'text': content}
          ]
        });
      }
    }

    // Add latest user message
    if (base64Image != null) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': userMessage.isEmpty ? 'Describe this image.' : userMessage},
          {
            'inline_data': {
              'mime_type': 'image/jpeg',
              'data': base64Image,
            }
          }
        ]
      });
    } else {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': userMessage}
        ]
      });
    }

    return {
      'contents': contents,
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 4096,
      }
    };
  }

  /// Parser function: Extract text from Gemini REST API response.
  String parseGeminiResponse(dynamic data) {
    if (data is Map && data['candidates'] != null && (data['candidates'] as List).isNotEmpty) {
      final parts = data['candidates'][0]['content']?['parts'] as List?;
      if (parts != null && parts.isNotEmpty) {
        final text = parts[0]['text'] as String?;
        if (text != null && text.isNotEmpty) return text.trim();
      }
    }
    throw Exception('Invalid Gemini API response payload');
  }
}
