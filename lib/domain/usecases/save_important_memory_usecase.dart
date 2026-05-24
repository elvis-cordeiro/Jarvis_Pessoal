import '../services/importance_detector.dart';
import '../services/personality_service.dart';
import '../../data/repositories/memory_repository.dart';

class SaveImportantMemoryUseCase {
  final MemoryRepository memoryRepository;
  final ImportanceDetector importanceDetector;
  final PersonalityService personalityService;

  SaveImportantMemoryUseCase({
    required this.memoryRepository,
    required this.importanceDetector,
    required this.personalityService,
  });

  /// Fluxo principal: Analisa a conversa e decide se deve salvar
  Future<void> call({
    required String userMessage,
    required String jarvisResponse,
    bool askUserConfirmation = true,   // Se deve perguntar antes de salvar
  }) async {
    
    // 1. Verifica se o assunto é importante
    final isImportant = importanceDetector.isImportant(
      userMessage, 
      jarvisResponse: jarvisResponse,
    );

    if (!isImportant) {
      return; // Não faz nada se não for importante
    }

    // 2. Se não precisar pedir confirmação, salva direto
    if (!askUserConfirmation) {
      await memoryRepository.saveLongTermMemory(
        content: userMessage,
        category: 'rotina', // ou 'personalidade', 'preferencias', etc.
      );
      return;
    }

    // 3. Aqui vamos disparar a pergunta para o usuário (via UI ou voz)
    // Por enquanto vamos imprimir no console (depois conectamos com a interface)
    print('🧠 Jarvis detectou assunto importante.');
    print('🤖 Jarvis: Senhor, eu vejo que esse assunto é de relativa importância.');
    print('Deseja que eu salve isso na minha memória de longo prazo (10 anos)?');
    
    // TODO: No futuro, vamos aguardar resposta do usuário ("Sim" ou "Não")
    // e então salvar ou não.
  }

  /// Método para salvar diretamente (usado quando o usuário disser "Sim")
  Future<void> saveConfirmed({
    required String content,
    String category = 'general',
  }) async {
    await memoryRepository.saveLongTermMemory(
      content: content,
      category: category,
    );
    
    print('✅ Memorizado com sucesso na memória permanente!');
  }
}