import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'personality_service.dart';

class GeminiService {
  final PersonalityService personalityService;
  late final GenerativeModel model;

GeminiService(this.personalityService) {
  final apiKey = dotenv.env['GEMINI_API_KEY'];

  if (apiKey == null || apiKey.isEmpty || apiKey == 'SUA_CHAVE_AQUI') {
    print('❌ GEMINI_API_KEY não encontrada ou inválida no .env!');
    throw Exception('Chave da API do Gemini não configurada corretamente.');
  }

  print('✅ Gemini API Key carregada com sucesso!');

  model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: apiKey,
  );
}

  Future<String> generateResponse(String userMessage) async {
    try {
      final systemPrompt = await personalityService.getSystemPrompt();

      final prompt = [
        Content.text(systemPrompt),
        Content.text("Usuário: $userMessage"),
      ];

      final response = await model.generateContent(prompt);
      return response.text ?? "Não consegui entender direito, mestre. Pode repetir?";
    } catch (e) {
      print('Erro no Gemini: $e');
      return "Mestre, estou com dificuldade de me conectar agora... Tenta de novo?";
    }
  }
}