import 'package:drift/drift.dart';
import '../../data/database/app_database.dart';
import 'importance_detector.dart';
import 'llm_memory_evaluator.dart';

class PersonalityService {
  final AppDatabase db;
  final ImportanceDetector importanceDetector;
  final LLMMemoryEvaluator llmEvaluator;

  PersonalityService({
    required this.db,
    required this.importanceDetector,
    required this.llmEvaluator,
  });

  /// Monta o prompt completo da personalidade do Jarvis
  Future<String> getSystemPrompt() async {
    final settings = await db.select(db.userSettings).getSingleOrNull();

    // Busca memórias de personalidade de longo prazo
    final longMemories = await (db.select(db.longTermMemory)
          ..where((tbl) => tbl.category.equals('personalidade') |
              tbl.category.equals('preferencias')))
        .get();

    String memoriesText = longMemories.map((m) => "- ${m.content}").join("\n");

    final baseName = settings?.jarvisName ?? 'Jarvis';

    return '''
Você é $baseName, um assistente pessoal inteligente, leal e conversacional.
Fala de forma natural, como um amigo brasileiro sincero. 
Use "mestre", "senhor" ou "Elvis" ocasionalmente.
Seja opinativo, mas educado. Mantenha o papo fluindo fazendo perguntas.

Informações importantes sobre o Elvis (memória de longo prazo):
$memoriesText

Sempre tente manter a conversa natural. Quando for relevante, pergunte se deve salvar algo na memória de longo prazo.
''';
  }

  /// Decide se deve perguntar para salvar na memória longa
  Future<bool> shouldAskToSaveMemory(String userMessage, String jarvisResponse) async {
    final isImportant = importanceDetector.isImportant(userMessage, jarvisResponse: jarvisResponse);
    
    if (!isImportant) return false;

    // Pode evoluir para usar o LLM evaluator aqui no futuro
    return true;
  }
}