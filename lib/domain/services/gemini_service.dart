import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'personality_service.dart';

enum JarvisConnectionStatus { online, offline, degraded }

class GeminiService {
  final PersonalityService personalityService;

  JarvisConnectionStatus _status = JarvisConnectionStatus.online;
  JarvisConnectionStatus get status => _status;

  GeminiService(this.personalityService);

  Future<String> sendMessage(String userMessage) async {
    final hasInternet = await _checkConnectivity();

    if (!hasInternet) {
      _status = JarvisConnectionStatus.offline;
      return await _offlineResponse(userMessage);
    }

    final systemPrompt = await personalityService.getSystemPrompt();
    final wasOffline = _status != JarvisConnectionStatus.online;

    // Ordem de prioridade dos provedores
    final providers = [
      () => _tryGemini(systemPrompt, userMessage),
      () => _tryOpenRouter(systemPrompt, userMessage),
      () => _trySambanova(systemPrompt, userMessage),
      () => _tryCloudflare(systemPrompt, userMessage),
      () => _tryHuggingFace(systemPrompt, userMessage),
    ];

    for (final provider in providers) {
      final result = await provider();
      if (result != null) {
        final wasDown = _status != JarvisConnectionStatus.online;
        _status = JarvisConnectionStatus.online;
        return wasDown || wasOffline
            ? 'Senhor, voltamos a operar em plena capacidade. Conexão restabelecida.\n\n$result'
            : result;
      }
    }

    _status = JarvisConnectionStatus.offline;
    return await _offlineResponse(userMessage);
  }

  // ==================== GEMINI ====================
  Future<String?> _tryGemini(String systemPrompt, String userMessage) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty || apiKey == 'SUA_CHAVE_AQUI') return null;

    final models = [
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
    ];

    for (final model in models) {
      try {
        final response = await http.post(
          Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'system_instruction': {
              'parts': [{'text': systemPrompt}]
            },
            'contents': [
              {
                'role': 'user',
                'parts': [{'text': userMessage}]
              }
            ],
            'generationConfig': {
              'temperature': 0.85,
              'maxOutputTokens': 2048,
            },
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['candidates'][0]['content']['parts'][0]['text'] as String;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // ==================== OPENROUTER ====================
  Future<String?> _tryOpenRouter(String systemPrompt, String userMessage) async {
    final apiKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';
    if (apiKey.isEmpty) return null;

    final models = [
      'meta-llama/llama-3.3-70b-instruct:free',
      'mistralai/mistral-7b-instruct:free',
      'qwen/qwen-2.5-72b-instruct:free',
    ];

    for (final model in models) {
      try {
        final response = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
            'HTTP-Referer': 'https://jarvis-pessoal.app',
            'X-Title': 'Jarvis Pessoal',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userMessage},
            ],
            'max_tokens': 2048,
            'temperature': 0.85,
          }),
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['choices'][0]['message']['content'] as String;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // ==================== SAMBANOVA ====================
  Future<String?> _trySambanova(String systemPrompt, String userMessage) async {
    final apiKey = dotenv.env['SAMBANOVA_API_KEY'] ?? '';
    if (apiKey.isEmpty) return null;

    final models = [
      'Meta-Llama-3.3-70B-Instruct',
      'Meta-Llama-3.1-8B-Instruct',
    ];

    for (final model in models) {
      try {
        final response = await http.post(
          Uri.parse('https://api.sambanova.ai/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userMessage},
            ],
            'max_tokens': 2048,
            'temperature': 0.85,
          }),
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['choices'][0]['message']['content'] as String;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // ==================== CLOUDFLARE ====================
  Future<String?> _tryCloudflare(String systemPrompt, String userMessage) async {
    final apiKey = dotenv.env['CLOUDFLARE_API_KEY'] ?? '';
    final accountId = dotenv.env['CLOUDFLARE_ACCOUNT_ID'] ?? '';
    if (apiKey.isEmpty || accountId.isEmpty) return null;

    final models = [
      '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
      '@cf/mistral/mistral-7b-instruct-v0.1',
    ];

    for (final model in models) {
      try {
        final response = await http.post(
          Uri.parse(
            'https://api.cloudflare.com/client/v4/accounts/$accountId/ai/run/$model',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userMessage},
            ],
            'max_tokens': 2048,
          }),
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['result']['response'] as String;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // ==================== HUGGING FACE ====================
  Future<String?> _tryHuggingFace(String systemPrompt, String userMessage) async {
    final apiKey = dotenv.env['HUGGINGFACE_API_KEY'] ?? '';
    if (apiKey.isEmpty) return null;

    final models = [
      'Qwen/Qwen2.5-72B-Instruct',
      'meta-llama/Llama-3.3-70B-Instruct',
      'mistralai/Mistral-7B-Instruct-v0.3',
    ];

    for (final model in models) {
      try {
        final response = await http.post(
          Uri.parse(
            'https://router.huggingface.co/v1/chat/completions',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userMessage},
            ],
            'max_tokens': 2048,
            'temperature': 0.85,
          }),
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['choices'][0]['message']['content'] as String;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // ==================== OFFLINE ====================
  Future<String> _offlineResponse(String userMessage) async {
    final lower = userMessage.toLowerCase();
    final systemPrompt = await personalityService.getSystemPrompt();
    final hasMemories = !systemPrompt.contains('Nenhuma ainda.');

    if (lower.contains('oi') ||
        lower.contains('olá') ||
        lower.contains('boa') ||
        lower.contains('bom dia') ||
        lower.contains('boa tarde') ||
        lower.contains('boa noite') ||
        lower.contains('voltou') ||
        lower.contains('online')) {
      return 'Senhor, no momento estou operando em modo offline — '
          'minha conexão com os servidores está indisponível. '
          'Posso conversar sobre assuntos que já conheço, '
          'mas não consigo responder dúvidas sobre temas ainda não discutidos. '
          'Estou monitorando e avisarei assim que voltar.';
    }

    if (hasMemories) {
      return 'Senhor, estou temporariamente offline. '
          'Tenho acesso às minhas memórias sobre o senhor, '
          'mas minha capacidade está limitada no momento. '
          'Continuarei monitorando a conexão.';
    }

    return 'Senhor, no momento estou com problemas de conexão. '
        'Ainda consigo conversar, porém não consigo realizar pesquisas '
        'ou responder dúvidas sobre temas ainda não discutidos. '
        'Assim que a conexão for restabelecida, avisarei imediatamente.';
  }

  // ==================== CONECTIVIDADE ====================
  Future<bool> _checkConnectivity() async {
    try {
      final result = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return result.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}